import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, waitFor, within, fireEvent, cleanup } from '@testing-library/preact';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse, buildStructuredErrorResponse } from './mocks/server';
import {
  catalogBody,
  catalogWireEntry,
  JSON_FEED_PREVIEW_PATH,
  jsonPreviewItems,
  metadataBody,
} from './mocks/apiFixtures';
import { App } from '../components/App';
import { COPY } from '../journey/copy';
import { resetAccessTokenMemory } from '../session/accessToken';

const EXAMPLE_URL = 'https://example.com/articles';
const DIRECTORY_HREF = 'https://html2rss.github.io/feed-directory/#!url=http%3A%2F%2Flocalhost%3A3000%2F';
const ACCESS_TOKEN = 'member-token';

const fao = catalogWireEntry({
  id: 'fao.org/newsroom',
  channelUrl: 'https://www.fao.org/newsroom',
  title: 'FAO Newsroom',
});
const anthropic = catalogWireEntry({
  id: 'anthropic.com/news',
  channelUrl: 'https://www.anthropic.com/news',
  title: 'Anthropic — News',
});
const bbcMundo = catalogWireEntry({
  id: 'bbc.com/mundo',
  channelUrl: 'https://www.bbc.com/mundo',
  title: 'BBC — Mundo',
});
const bbcSounds = catalogWireEntry({
  id: 'bbc.co.uk/available_episodes',
  path: '/bbc.co.uk/available_episodes.rss',
  channelUrl: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player',
  title: 'BBC Sounds — Programme episodes',
  parameterDefaults: { id: 'b006wkfp' },
});

function useSuccessfulCreate(createCount?: { value: number }) {
  server.use(
    http.post('/api/v1/feeds', async ({ request }) => {
      if (createCount) createCount.value += 1;
      const body = (await request.json()) as { url: string; selectors?: unknown };
      return HttpResponse.json(
        buildFeedResponse({
          url: body.url,
          feed_token: 'generated-token',
          public_url: '/api/v1/feeds/generated-token',
          json_public_url: '/api/v1/feeds/generated-token.json',
        }),
        { status: 201 }
      );
    })
  );
}

const EMPTY_EXTRACTION_NOTICE = 'We could not extract feed items from this page yet.';

function extractionEmptyResponse(message = EMPTY_EXTRACTION_NOTICE) {
  return HttpResponse.json(
    buildStructuredErrorResponse({
      code: 'EXTRACTION_EMPTY',
      message,
      kind: 'input',
      retryable: false,
      next_action: 'correct_input',
      retry_action: 'none',
    }),
    { status: 422 }
  );
}

async function createWithUrl(user: Awaited<ReturnType<typeof userEvent.setup>>, url = EXAMPLE_URL) {
  await user.type(screen.getByLabelText(COPY.urlLabel), url);
  await user.click(screen.getByRole('button', { name: COPY.createFeed }));
}

async function renderApp(user = userEvent.setup()) {
  render(<App />);
  await screen.findByLabelText(COPY.urlLabel);
  return user;
}

describe('App', () => {
  beforeEach(() => {
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    localStorage.clear();
    sessionStorage.clear();
    resetAccessTokenMemory();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('shows feed result when create and JSON preview succeed', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    const pending = Promise.withResolvers<Response>();
    server.use(
      http.post('/api/v1/feeds', () => pending.promise),
      http.get(JSON_FEED_PREVIEW_PATH, ({ request }) => {
        expect(request.headers.get('accept')).toBe('application/feed+json');
        return HttpResponse.json(jsonPreviewItems, {
          headers: { 'content-type': 'application/feed+json' },
        });
      })
    );

    const user = await renderApp();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();

    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));

    expect(screen.getByRole('button', { name: COPY.creating })).toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'submitting');
    expect(document.querySelector('.notice[data-state="loading"]')).toBeNull();

    pending.resolve(
      HttpResponse.json(
        buildFeedResponse({
          url: EXAMPLE_URL,
          feed_token: 'generated-token',
          public_url: '/api/v1/feeds/generated-token',
          json_public_url: '/api/v1/feeds/generated-token.json',
        }),
        { status: 201 }
      )
    );

    await screen.findByText(COPY.feedReady);
    expect(screen.getByText('Example Feed')).toBeInTheDocument();
    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'ready');
    await waitFor(() => {
      expect(screen.getByText(COPY.previewItemCount(1))).toBeInTheDocument();
      expect(screen.getByText('Sample preview item')).toBeInTheDocument();
    });
  });

  it('shows lean starters and hides them once the URL is non-empty', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(http.get('/api/v1/configs', () => HttpResponse.json(catalogBody([fao], [fao.id]))));

    const user = await renderApp();

    await screen.findByRole('link', { name: 'FAO Newsroom' });
    expect(screen.getByRole('list', { name: COPY.feedDirectory })).toBeInTheDocument();
    expect(screen.queryByText(COPY.feedDirectoryIntro)).not.toBeInTheDocument();

    await user.type(screen.getByLabelText(COPY.urlLabel), 'example.com');
    expect(screen.queryByRole('link', { name: 'FAO Newsroom' })).not.toBeInTheDocument();
    expect(screen.queryByRole('list', { name: COPY.feedDirectory })).not.toBeInTheDocument();
  });

  it('opens the active catalog hit with ArrowDown then Enter without creating', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    const createCount = { value: 0 };
    useSuccessfulCreate(createCount);
    server.use(http.get('/api/v1/configs', () => HttpResponse.json(catalogBody([bbcMundo, bbcSounds]))));

    const user = await renderApp();
    await waitFor(() => {
      expect(screen.getAllByRole('link', { name: COPY.browseFeedDirectory(2) }).length).toBeGreaterThan(0);
    });
    const urlField = screen.getByLabelText(COPY.urlLabel);
    fireEvent.input(urlField, { target: { value: 'bbc' } });
    await screen.findByRole('listbox', { name: COPY.catalogFindHitsLabel });

    urlField.focus();
    await user.keyboard('{ArrowDown}');
    const active = screen.getByRole('option', { name: 'BBC Sounds — Programme episodes' });
    expect(active).toHaveAttribute('aria-selected', 'true');
    expect(active).toHaveAttribute('href', '/bbc.co.uk/available_episodes.rss?id=b006wkfp');
    expect(urlField).toHaveAttribute('aria-activedescendant', active.id);

    await user.keyboard('{Enter}');

    expect(createCount.value).toBe(0);
  });

  it('does not double-create when Enter key-repeats', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    const createCount = { value: 0 };
    useSuccessfulCreate(createCount);

    await renderApp();
    const urlField = screen.getByLabelText(COPY.urlLabel);
    fireEvent.input(urlField, { target: { value: EXAMPLE_URL } });
    fireEvent.keyDown(urlField, { key: 'Enter' });
    fireEvent.keyDown(urlField, { key: 'Enter', repeat: true });
    fireEvent.keyDown(urlField, { key: 'Enter', repeat: true });

    await screen.findByText(COPY.feedReady);
    expect(createCount.value).toBe(1);
  });

  it('surfaces retryable create errors with Decision copy', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            message: 'Access denied',
            kind: 'server',
            retryable: true,
            next_action: 'retry',
            retry_action: 'primary',
          }),
          { status: 500 }
        )
      )
    );

    const user = await renderApp();
    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByText(COPY.createFailedRetryTitle);
    expect(screen.getByText('Access denied')).toBeInTheDocument();
  });

  it('opens unresolved on EXTRACTION_EMPTY with studio; stays create error when studio is off', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(http.post('/api/v1/feeds', () => extractionEmptyResponse()));

    let user = await renderApp();
    await createWithUrl(user);

    await waitFor(() => {
      expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'unresolved');
    });
    expect(location.hash).toBe('#/result');
    expect(screen.getByText(EXAMPLE_URL)).toBeInTheDocument();
    expect(screen.getByText(EMPTY_EXTRACTION_NOTICE)).toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(screen.getByLabelText(COPY.itemsSelector)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.saveAndGenerate })).toHaveClass('btn--primary');

    cleanup();
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    resetAccessTokenMemory();
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(
      http.get(/\/api\/v1\/?$/, () => HttpResponse.json(metadataBody({ isStudioEnabled: false }))),
      http.post('/api/v1/feeds', () => extractionEmptyResponse())
    );
    user = await renderApp();
    await createWithUrl(user);

    await screen.findByText(COPY.createFailedTitle);
    expect(screen.getByText(EMPTY_EXTRACTION_NOTICE)).toBeInTheDocument();
    expect(document.querySelector('.result-shell')).not.toBeInTheDocument();
    expect(location.hash).toMatch(/#\/create/);
  });

  it('mints ready on unresolved save with items, or stays unresolved when save is still empty', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    const secondNotice = 'Still no items with these selectors.';
    let createCalls = 0;
    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        createCalls += 1;
        const body = (await request.json()) as { url?: string; selectors?: unknown };
        if (!body.selectors) return extractionEmptyResponse();
        return extractionEmptyResponse(createCalls === 1 ? EMPTY_EXTRACTION_NOTICE : secondNotice);
      })
    );

    let user = await renderApp();
    await createWithUrl(user);
    await waitFor(() => {
      expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'unresolved');
    });
    expect(screen.getByText(EMPTY_EXTRACTION_NOTICE)).toBeInTheDocument();

    let save = screen.getByRole('button', { name: COPY.saveAndGenerate });
    await waitFor(() => expect(save).toBeEnabled());
    await user.click(save);

    await waitFor(() => {
      expect(screen.getAllByText(secondNotice)).toHaveLength(1);
    });
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'unresolved');
    expect(location.hash).toBe('#/result');
    expect(createCalls).toBeGreaterThanOrEqual(2);

    cleanup();
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    resetAccessTokenMemory();
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    createCalls = 0;
    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        createCalls += 1;
        const body = (await request.json()) as { url?: string; selectors?: unknown };
        if (!body.selectors) return extractionEmptyResponse();
        return HttpResponse.json(
          buildFeedResponse({
            url: body.url ?? EXAMPLE_URL,
            feed_token: 'minted-token',
            public_url: '/api/v1/feeds/minted-token',
            json_public_url: '/api/v1/feeds/minted-token.json',
          }),
          { status: 201 }
        );
      }),
      http.get(JSON_FEED_PREVIEW_PATH, () =>
        HttpResponse.json(jsonPreviewItems, {
          headers: { 'Content-Type': 'application/feed+json' },
        })
      )
    );
    user = await renderApp();
    await createWithUrl(user);
    await waitFor(() => {
      expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'unresolved');
    });
    save = screen.getByRole('button', { name: COPY.saveAndGenerate });
    await waitFor(() => expect(save).toBeEnabled());
    await user.click(save);

    await screen.findByText(COPY.feedReady);
    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'ready');
    expect(location.hash).toBe('#/result/minted-token');
    expect(screen.getByRole('button', { name: COPY.copyFeedUrl })).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.itemsSelector)).toBeInTheDocument();
  });

  it('shows instance metadata failure as a banner without create-error chrome', async () => {
    server.use(http.get(/\/api\/v1\/?$/, () => HttpResponse.json({ success: false }, { status: 503 })));

    render(<App />);
    await screen.findByText(COPY.instanceMetadataUnavailable);
    expect(screen.getByText(COPY.instanceUnavailable)).toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
  });

  it('keeps utility order for guest and member, remaps OpenAPI, and places logout before Docker', async () => {
    server.use(
      http.get(/\/api\/v1\/?$/, () =>
        HttpResponse.json(metadataBody({ openapiUrl: 'http://127.0.0.1:4000/openapi.yaml' }))
      )
    );

    await renderApp();

    const utilities = screen.getByLabelText(COPY.utilities);
    expect(
      [...utilities.querySelectorAll(':scope .utility-strip__items > a')].map((link) => link.textContent)
    ).toEqual([
      COPY.browseFeedDirectory(),
      COPY.bookmarkletTitle,
      COPY.dockerInstall,
      COPY.openapiSpec,
      COPY.sourceCode,
    ]);
    expect(screen.getByRole('link', { name: COPY.openapiSpec })).toHaveAttribute(
      'href',
      'http://localhost:3000/openapi.yaml'
    );
    expect(screen.getByRole('link', { name: COPY.browseFeedDirectory() })).toHaveAttribute(
      'href',
      DIRECTORY_HREF
    );

    cleanup();
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    await renderApp();
    await screen.findByRole('button', { name: COPY.logout });
    expect(
      [
        ...screen
          .getByLabelText(COPY.utilities)
          .querySelectorAll(':scope .utility-strip__items > a, :scope .utility-strip__items > button'),
      ].map((element) => element.textContent)
    ).toEqual([
      COPY.browseFeedDirectory(),
      COPY.bookmarkletTitle,
      COPY.logout,
      COPY.dockerInstall,
      COPY.openapiSpec,
      COPY.sourceCode,
    ]);
  });

  it('clears the access token and remounts create on logout', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);

    const user = await renderApp();
    await user.click(await screen.findByRole('button', { name: COPY.logout }));

    expect(localStorage.getItem('html2rss_access_token')).toBeNull();
    expect(sessionStorage.getItem('html2rss_access_token')).toBeNull();
    expect(location.hash).toMatch(/^#\/create/);
    expect(screen.queryByRole('button', { name: COPY.logout })).not.toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
  });

  it('prefills bookmarklet hash URLs over a saved draft', async () => {
    localStorage.setItem(
      'html2rss_feed_draft_state',
      JSON.stringify({ url: 'https://old.example.com/page' })
    );
    history.replaceState({}, '', 'http://localhost:3000/#/create?url=https%3A%2F%2Fexample.com%2Farticles');

    await renderApp();
    await waitFor(() => {
      expect(screen.getByLabelText(COPY.urlLabel)).toHaveValue(EXAMPLE_URL);
    });
    expect(screen.getByRole('link', { name: COPY.bookmarkletTitle }).getAttribute('href')).toContain(
      '/#/create?url='
    );
  });

  it('saves a token from the prompt and resumes create', async () => {
    useSuccessfulCreate();
    const user = await renderApp();

    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByRole('heading', { name: COPY.tokenTitle });
    expect(location.hash).toMatch(/^#\/token/);
    expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();

    await user.type(document.querySelector('#access-token') as HTMLInputElement, 'token-123');
    await user.click(screen.getByRole('button', { name: COPY.saveAndContinue }));

    await screen.findByText(COPY.feedReady);
    expect(localStorage.getItem('html2rss_access_token')).toBe('token-123');
    expect(sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('keeps Decision chrome when token save create fails non-auth onto create', async () => {
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            message: 'Upstream failed',
            kind: 'server',
            retryable: true,
            next_action: 'retry',
            retry_action: 'primary',
          }),
          { status: 500 }
        )
      )
    );

    const user = await renderApp();
    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByRole('heading', { name: COPY.tokenTitle });
    await user.type(document.querySelector('#access-token') as HTMLInputElement, 'token-123');
    await user.click(screen.getByRole('button', { name: COPY.saveAndContinue }));

    await waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });
    await screen.findByText(COPY.createFailedRetryTitle);
    expect(screen.getByText('Upstream failed')).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: COPY.tokenTitle })).not.toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'error');

    // Remount from token→create must keep Decision error (hasAutoSubmitted blocks wipe/auto-retry).
    await waitFor(() => {
      expect(screen.getByText(COPY.createFailedRetryTitle)).toBeInTheDocument();
      expect(screen.getByText('Upstream failed')).toBeInTheDocument();
      expect(location.hash).toMatch(/^#\/create/);
      expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'error');
    });
  });

  it('reopens the token gate on auth rejection and ignores non-token forbidden', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            code: 'UNAUTHORIZED',
            message: 'Authentication required',
            kind: 'auth',
            retryable: false,
            next_action: 'enter_token',
            retry_action: 'none',
          }),
          { status: 401 }
        )
      )
    );

    let user = await renderApp();
    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByText(COPY.tokenRejected);
    expect(screen.getByRole('heading', { name: COPY.tokenTitle })).toBeInTheDocument();
    expect(localStorage.getItem('html2rss_access_token')).toBeNull();

    cleanup();
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    resetAccessTokenMemory();
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            code: 'FORBIDDEN',
            message: 'URL not allowed for this account',
            kind: 'server',
            retryable: false,
            next_action: 'none',
            retry_action: 'none',
          }),
          { status: 403 }
        )
      )
    );
    user = await renderApp();
    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByText('URL not allowed for this account');
    expect(screen.queryByRole('heading', { name: COPY.tokenTitle })).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.tokenRejected)).not.toBeInTheDocument();
    expect(localStorage.getItem('html2rss_access_token')).toBe(ACCESS_TOKEN);
  });

  it('clears creation chrome when remounting create via BrandLockup', async () => {
    localStorage.setItem('html2rss_access_token', ACCESS_TOKEN);
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            message: 'Upstream failed',
            kind: 'server',
            retryable: true,
            next_action: 'retry',
            retry_action: 'primary',
          }),
          { status: 500 }
        )
      )
    );

    const user = await renderApp();
    await user.type(screen.getByLabelText(COPY.urlLabel), EXAMPLE_URL);
    await user.click(screen.getByRole('button', { name: COPY.createFeed }));
    await screen.findByText(COPY.createFailedRetryTitle);

    await user.click(screen.getByRole('link', { name: 'html2rss' }));

    await waitFor(() => {
      expect(screen.queryByText(COPY.createFailedRetryTitle)).not.toBeInTheDocument();
      expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    });
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
  });

  it('promotes starters when feed creation is disabled', async () => {
    server.use(
      http.get(/\/api\/v1\/?$/, () =>
        HttpResponse.json({
          success: true,
          data: {
            api: {
              name: 'html2rss-web API',
              description: 'd',
              openapi_url: 'https://example.test/openapi.yaml',
            },
            instance: {
              feed_creation: { enabled: false, access_token_required: false },
              studio: { enabled: true },
              catalog: { enabled: true, url: 'https://api.html2rss.dev/api/v1/configs' },
            },
          },
        })
      ),
      http.get('/api/v1/configs', () => HttpResponse.json(catalogBody([fao], [fao.id])))
    );

    await renderApp();
    await waitFor(() => {
      expect(document.querySelector('.notice__title')?.textContent).toBe(COPY.feedDirectory);
    });
    expect(screen.getByRole('link', { name: 'FAO Newsroom' })).toBeInTheDocument();
    expect(screen.getByText(COPY.creationDisabled)).toBeInTheDocument();
  });

  it('lists catalog find hits for a text query', async () => {
    server.use(
      http.get('/api/v1/configs', () => HttpResponse.json(catalogBody([bbcMundo, bbcSounds, anthropic])))
    );

    const user = await renderApp();
    await user.type(screen.getByLabelText(COPY.urlLabel), 'bbc');

    await screen.findByRole('option', { name: 'BBC — Mundo' });
    expect(screen.getByRole('option', { name: 'BBC Sounds — Programme episodes' })).toHaveAttribute(
      'href',
      '/bbc.co.uk/available_episodes.rss?id=b006wkfp'
    );
    expect(screen.getByRole('listbox', { name: COPY.catalogFindHitsLabel })).toBeInTheDocument();
    expect(within(screen.getByRole('status')).getByText(COPY.catalogFindHint)).toBeInTheDocument();
  });
});
