/** Pure API wire fixtures shared by MSW and Playwright. */

export type MetadataOptions = {
  isTokenRequired?: boolean;
  isCatalogEnabled?: boolean;
  isStudioEnabled?: boolean;
  openapiUrl?: string;
};

export function metadataBody({
  isTokenRequired = true,
  isCatalogEnabled = true,
  isStudioEnabled = true,
  openapiUrl = 'https://example.test/openapi.yaml',
}: MetadataOptions = {}) {
  return {
    success: true,
    data: {
      api: {
        name: 'html2rss-web API',
        description: 'RESTful API for converting websites to RSS feeds',
        openapi_url: openapiUrl,
      },
      instance: {
        feed_creation: { enabled: true, access_token_required: isTokenRequired },
        studio: { enabled: isStudioEnabled },
        catalog: {
          enabled: isCatalogEnabled,
          url: 'https://api.html2rss.dev/api/v1/configs',
        },
      },
    },
  };
}

export const emptyCatalog = {
  success: true,
  data: { configs: [] },
  meta: { total: 0, catalog_version: 2, starters: [] },
};

export type CatalogWireEntry = {
  id: string;
  path?: string;
  channelUrl: string;
  title: string;
  summary?: string;
  parameterDefaults?: Record<string, string>;
  lastResultState?: string;
};

export function catalogWireEntry({
  id,
  path,
  channelUrl,
  title,
  summary,
  parameterDefaults = {},
  lastResultState = 'unknown',
}: CatalogWireEntry) {
  return {
    id,
    path: path ?? `/${id}.rss`,
    channel: { url: channelUrl },
    directory: { title, summary: summary ?? `${title} description.` },
    parameters: { schema: {}, defaults: parameterDefaults },
    last_result: { state: lastResultState },
  };
}

export function catalogBody(entries: ReturnType<typeof catalogWireEntry>[], starters: string[] = []) {
  return {
    success: true,
    data: { configs: entries },
    meta: { total: entries.length, catalog_version: 2, starters },
  };
}

export type CreatedFeedOverrides = {
  id?: string;
  name?: string;
  url?: string;
  feed_token?: string;
  public_url?: string;
  json_public_url?: string;
  created_at?: string;
  updated_at?: string;
};

export function createdFeedBody(overrides: CreatedFeedOverrides = {}) {
  const timestamp = overrides.created_at ?? '2026-04-05T08:59:00.000Z';
  const token = overrides.feed_token ?? 'generated-token';
  return {
    success: true,
    data: {
      feed: {
        id: overrides.id ?? 'feed-123',
        name: overrides.name ?? 'Example Feed',
        url: overrides.url ?? 'https://example.com/articles',
        feed_token: token,
        public_url: overrides.public_url ?? `/api/v1/feeds/${token}`,
        json_public_url: overrides.json_public_url ?? `/api/v1/feeds/${token}.json`,
        created_at: timestamp,
        updated_at: overrides.updated_at ?? '2026-04-05T09:00:00.000Z',
      },
    },
  };
}

export function buildFeedResponse(overrides: CreatedFeedOverrides = {}) {
  return { ...createdFeedBody(overrides), meta: { created: true } };
}

export type StructuredErrorOverrides = {
  code?: string;
  message?: string;
  kind?: 'auth' | 'input' | 'network' | 'server';
  retryable?: boolean;
  next_action?: 'enter_token' | 'correct_input' | 'retry' | 'wait' | 'none';
  retry_action?: 'alternate' | 'primary' | 'none';
};

export function buildStructuredErrorResponse(overrides: StructuredErrorOverrides = {}) {
  return {
    success: false,
    error: {
      code: overrides.code ?? 'INTERNAL_SERVER_ERROR',
      message: overrides.message ?? 'Internal Server Error',
      kind: overrides.kind ?? 'server',
      retryable: overrides.retryable ?? false,
      next_action: overrides.next_action ?? 'none',
      retry_action: overrides.retry_action ?? 'none',
    },
  };
}

export function pageUrlFrom(body: unknown): string | undefined {
  if (typeof body === 'object' && body && 'url' in body && typeof body.url === 'string' && body.url.trim()) {
    return body.url;
  }
  return undefined;
}

export function selectorsFromValidateRequest(body: unknown): unknown {
  if (typeof body === 'object' && body && 'selectors' in body && body.selectors !== undefined) {
    return body.selectors;
  }
  return { items: { selector: 'a[href]', enhance: false } };
}

export function validateYamlForSelectors(selectors: unknown, url?: string): string {
  const channel = url ? `channel:\n  url: ${url}\n` : '';
  if (
    typeof selectors === 'object' &&
    selectors &&
    'items' in selectors &&
    typeof selectors.items === 'object' &&
    selectors.items &&
    'selector' in selectors.items &&
    typeof selectors.items.selector === 'string'
  ) {
    const enhance =
      'enhance' in selectors.items && selectors.items.enhance === true ? '\n    enhance: true' : '';
    return `${channel}selectors:\n  items:\n    selector: ${selectors.items.selector}${enhance}\n`;
  }
  return `${channel}selectors: {}\n`;
}

export function validateSuccessBody(selectors?: unknown, yaml?: string) {
  const resolved = selectors ?? { items: { selector: 'article' } };
  return {
    success: true,
    data: {
      report: { success: true, issues: [] },
      selectors: resolved,
      yaml: yaml ?? validateYamlForSelectors(resolved),
    },
  };
}

export type SuggestCandidateFixture = {
  selector: string;
  enhance?: boolean;
  sample?: string;
};

export type SuggestBuckets = {
  items?: SuggestCandidateFixture[];
  title?: SuggestCandidateFixture[];
  link?: SuggestCandidateFixture[];
  published?: SuggestCandidateFixture[];
};

function mapSuggestField(entries: SuggestCandidateFixture[] = []) {
  return entries.map((entry) => ({
    selector: entry.selector,
    sample: entry.sample ?? entry.selector,
  }));
}

export function suggestSuccessBody(buckets: SuggestBuckets = {}, extras: Record<string, unknown> = {}) {
  return {
    success: true,
    data: {
      candidates: {
        items: (buckets.items ?? []).map((entry) => ({
          selector: entry.selector,
          enhance: entry.enhance === true,
          sample: entry.sample ?? entry.selector,
        })),
        title: mapSuggestField(buckets.title),
        link: mapSuggestField(buckets.link),
        published: mapSuggestField(buckets.published),
      },
      segment_strategy: 'list',
      admission_drops: { chrome: 0 },
      ...extras,
    },
  };
}

export const DEFAULT_SUGGEST_BUCKETS: SuggestBuckets = {
  items: [{ selector: 'article', enhance: true, sample: 'Sample headline' }],
};

export function studioPreviewSuccessBody(
  items: Array<Record<string, unknown>> = [
    {
      title: 'Studio meadow item',
      url: 'https://example.com/studio-item',
      published_at: '2024-01-02',
    },
  ]
) {
  return {
    success: true,
    data: {
      item_count: items.length,
      sample_items: items,
      quality_report: { warnings: [], metrics: { short_title_count: 0 } },
      // eslint-disable-next-line unicorn/no-null -- wire absence is null
      failure_kind: null,
      validation_issues: [],
    },
  };
}

export const jsonPreviewItems = {
  items: [
    {
      title: 'Sample preview item',
      content_text: 'Current preview fetch includes rendered content.',
      date_published: '2026-04-05T09:00:00.000Z',
      url: 'https://example.com/articles/sample-preview-item',
    },
  ],
};

export const JSON_FEED_PREVIEW_PATH = /\/api\/v1\/feeds\/[^/?#]+\.json$/;
