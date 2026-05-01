import { useEffect, useRef, useState } from 'preact/hooks';
import type {
  CreatedFeedResult,
  FeedCreationError,
  FeedNextAction,
  FeedPreviewItem,
  FeedPreviewWarning,
  FeedRecord,
  FeedRetryAction,
  FeedWorkflowState,
} from '../api/contracts';
import { normalizeUserUrl } from '../utils/url';

interface ConversionState {
  isConverting: boolean;
  result?: CreatedFeedResult;
  error?: FeedCreationError;
}

interface RawFeedRecord {
  id?: unknown;
  name?: unknown;
  url?: unknown;
  feed_token?: unknown;
  public_url?: unknown;
  json_public_url?: unknown;
  created_at?: unknown;
  updated_at?: unknown;
}

interface RawFeedPayload {
  feed?: RawFeedRecord;
}

interface RawApiResponse {
  success?: unknown;
  data?: RawFeedPayload;
  error?: unknown;
}

interface RawErrorEnvelope {
  kind?: unknown;
  code?: unknown;
  retryable?: unknown;
  next_action?: unknown;
  retry_action?: unknown;
  message?: unknown;
}

interface JsonFeedResponse {
  items?: unknown[];
}

interface PreviewLoadResult {
  items: FeedPreviewItem[];
  warnings: FeedPreviewWarning[];
  workflowState: Extract<FeedWorkflowState, 'preview_ready' | 'preview_failed'>;
}

const PREVIEW_RETRY_DELAYS_MS = [260, 620, 1180, 1800] as const;
const PREVIEW_UNAVAILABLE_MESSAGE = 'Preview unavailable right now.';
const PREVIEW_DEGRADED_MESSAGE = 'Preview content is partially degraded right now.';

export function useFeedConversion() {
  const requestIdReference = useRef(0);
  const previewAbortControllerReference = useRef<AbortController | undefined>(undefined);
  const [state, setState] = useState<ConversionState>({ isConverting: false });

  const cancelPreview = () => {
    previewAbortControllerReference.current?.abort();
    previewAbortControllerReference.current = undefined;
  };

  useEffect(
    () => () => {
      requestIdReference.current += 1;
      cancelPreview();
    },
    []
  );

  async function convertFeed(url: string, token: string) {
    const normalizedUrl = normalizeUserUrl(url);

    if (!normalizedUrl) throw buildLocalError('Source URL is required.', 'input', 'correct_input');
    if (!isValidHttpUrl(normalizedUrl))
      throw buildLocalError('Invalid URL format.', 'input', 'correct_input');

    const requestId = requestIdReference.current + 1;
    requestIdReference.current = requestId;
    cancelPreview();
    setState((previous) => ({ ...previous, isConverting: true, error: undefined }));

    try {
      const feed = await requestFeedCreation(normalizedUrl, token);
      const result = buildCreatedFeedResult(feed);
      publishResult(result, requestId, setState, requestIdReference);
      void hydrateFeedPreview(feed, requestId, setState, requestIdReference, previewAbortControllerReference);
      return result;
    } catch (error) {
      const structuredError = normalizeFeedCreationError(error);
      failConversion(setState, structuredError);
      throw structuredError;
    }
  }

  const clearResult = () => {
    globalThis.document?.body?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    requestIdReference.current += 1;
    cancelPreview();
    setState({ isConverting: false });
  };

  const clearError = () => {
    setState((previous) => ({ ...previous, error: undefined }));
  };

  const retryPreviewFetch = () => {
    const currentResult = state.result;
    if (!currentResult) return;

    const requestId = requestIdReference.current + 1;
    requestIdReference.current = requestId;
    cancelPreview();

    void hydrateFeedPreview(
      currentResult.feed,
      requestId,
      setState,
      requestIdReference,
      previewAbortControllerReference
    );
  };

  return {
    isConverting: state.isConverting,
    result: state.result,
    error: state.error,
    convertFeed,
    clearError,
    clearResult,
    retryPreviewFetch,
  };
}

async function requestFeedCreation(url: string, token: string): Promise<FeedRecord> {
  const response = await globalThis.fetch(resolveApiUrl('feeds'), {
    method: 'POST',
    headers: buildCreateHeaders(token),
    body: JSON.stringify({ url }),
  });

  const payload = await readJsonResponse<RawApiResponse>(response);

  if (!response.ok) {
    throw normalizeFeedCreationErrorFromResponse(response.status, payload?.error, payload);
  }

  const feed = normalizeFeedRecord(payload?.data?.feed);
  if (!feed) {
    throw buildStructuredError(
      'server',
      'INVALID_RESPONSE',
      true,
      'retry',
      'primary',
      'Unable to start feed generation.',
      response.status
    );
  }

  return feed;
}

async function hydrateFeedPreview(
  feed: FeedRecord,
  requestId: number,
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  requestIdReference: { current: number },
  previewAbortControllerReference: { current: AbortController | undefined }
) {
  previewAbortControllerReference.current?.abort();
  const controller = new AbortController();
  previewAbortControllerReference.current = controller;

  commitResult(buildPreviewLoadingResult(feed), requestId, setState, requestIdReference);

  try {
    const previewResult = await loadPreviewItemsWithRetry(feed.json_public_url, controller.signal);
    if (requestIdReference.current !== requestId) return;

    commitResult(
      {
        feed,
        preview: {
          items: previewResult.items,
          isLoading: false,
        },
        workflowState: previewResult.workflowState,
        warnings: previewResult.warnings,
      },
      requestId,
      setState,
      requestIdReference
    );
  } catch (error) {
    if (isAbortError(error)) return;

    commitResult(
      {
        feed,
        preview: {
          items: [],
          isLoading: false,
        },
        workflowState: 'preview_failed',
        warnings: [buildPreviewWarning('PREVIEW_FAILED', PREVIEW_UNAVAILABLE_MESSAGE, true, 'retry')],
      },
      requestId,
      setState,
      requestIdReference
    );
  } finally {
    if (previewAbortControllerReference.current === controller) {
      previewAbortControllerReference.current = undefined;
    }
  }
}

async function loadPreviewItemsWithRetry(
  previewUrl: string,
  signal?: AbortSignal
): Promise<PreviewLoadResult> {
  const delays = [0, ...PREVIEW_RETRY_DELAYS_MS];
  let latestRetryableFailure: PreviewLoadResult | undefined;

  for (const [index, delayMs] of delays.entries()) {
    if (delayMs > 0) await wait(delayMs, signal);

    const result = await loadPreviewItems(previewUrl, signal);
    if (result.workflowState === 'preview_ready') return result;
    if (!result.warnings.some((warning) => warning.retryable)) return result;

    latestRetryableFailure = result;
    if (index === delays.length - 1) return result;
  }

  return (
    latestRetryableFailure ?? {
      items: [],
      warnings: [buildPreviewWarning('PREVIEW_FAILED', PREVIEW_UNAVAILABLE_MESSAGE, true, 'retry')],
      workflowState: 'preview_failed',
    }
  );
}

async function loadPreviewItems(previewUrl: string, signal?: AbortSignal): Promise<PreviewLoadResult> {
  let response: Response;

  try {
    response = await globalThis.fetch(resolveFetchUrl(previewUrl), {
      headers: { Accept: 'application/feed+json' },
      signal,
    });
  } catch (error) {
    if (isAbortError(error)) throw error;

    return {
      items: [],
      warnings: [buildPreviewWarning('PREVIEW_NETWORK_ERROR', PREVIEW_UNAVAILABLE_MESSAGE, true, 'retry')],
      workflowState: 'preview_failed',
    };
  }

  if (!response.ok) {
    return {
      items: [],
      warnings: [
        buildPreviewWarning(
          `PREVIEW_HTTP_${response.status}`,
          isTransientHttpStatus(response.status) ? PREVIEW_DEGRADED_MESSAGE : PREVIEW_UNAVAILABLE_MESSAGE,
          isTransientHttpStatus(response.status),
          isTransientHttpStatus(response.status) ? 'retry' : 'wait'
        ),
      ],
      workflowState: 'preview_failed',
    };
  }

  try {
    const payload = (await response.json()) as JsonFeedResponse;
    return {
      items: normalizePreviewItems(payload.items),
      warnings: [],
      workflowState: 'preview_ready',
    };
  } catch {
    return {
      items: [],
      warnings: [buildPreviewWarning('PREVIEW_INVALID_JSON', PREVIEW_UNAVAILABLE_MESSAGE, false, 'wait')],
      workflowState: 'preview_failed',
    };
  }
}

function buildCreatedFeedResult(feed: FeedRecord): CreatedFeedResult {
  return {
    feed,
    preview: {
      items: [],
      isLoading: false,
    },
    workflowState: 'created',
    warnings: [],
  };
}

function buildPreviewLoadingResult(feed: FeedRecord): CreatedFeedResult {
  return {
    feed,
    preview: {
      items: [],
      isLoading: true,
    },
    workflowState: 'preview_loading',
    warnings: [],
  };
}

function commitResult(
  result: CreatedFeedResult,
  requestId: number,
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  requestIdReference: { current: number }
) {
  setState((previous) => {
    if (requestIdReference.current !== requestId) {
      return previous;
    }

    return {
      ...previous,
      isConverting: false,
      error: undefined,
      result,
    };
  });
}

function publishResult(
  result: CreatedFeedResult,
  requestId: number,
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  requestIdReference: { current: number }
) {
  commitResult(result, requestId, setState, requestIdReference);
}

function failConversion(
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  error: FeedCreationError
) {
  setState((previous) => ({
    ...previous,
    isConverting: false,
    error,
  }));
}

function normalizeFeedCreationError(error: unknown): FeedCreationError {
  if (isFeedCreationError(error)) return error;

  if (error instanceof Error) {
    return buildStructuredError(
      'network',
      'NETWORK_ERROR',
      true,
      'retry',
      'primary',
      error.message || 'Unable to reach the server.'
    );
  }

  return buildStructuredError(
    'server',
    'UNKNOWN_ERROR',
    true,
    'retry',
    'primary',
    'Unable to complete feed creation.'
  );
}

function normalizeFeedCreationErrorFromResponse(
  status: number,
  errorPayload: unknown,
  payload?: RawApiResponse
): FeedCreationError {
  const envelope = resolveErrorEnvelope(errorPayload, payload);

  const kind = normalizeErrorKind(envelope?.kind, status);
  const retryable = normalizeBoolean(envelope?.retryable, defaultRetryableFromStatus(status, kind));
  const nextAction = normalizeNextAction(envelope?.next_action, kind, retryable);
  const retryAction = normalizeRetryAction(envelope?.retry_action, nextAction, retryable);
  const code = normalizeString(envelope?.code) || fallbackErrorCode(status, kind);
  const message = normalizeString(envelope?.message) || fallbackErrorMessage(status, kind, nextAction);

  return buildStructuredError(kind, code, retryable, nextAction, retryAction, message, status);
}

function resolveErrorEnvelope(errorPayload: unknown, payload?: RawApiResponse): RawErrorEnvelope | undefined {
  if (isErrorEnvelope(errorPayload)) return errorPayload;
  if (isErrorEnvelope(payload?.error)) return payload.error;
  if (isErrorEnvelope(payload)) return payload;
  return undefined;
}

function buildStructuredError(
  kind: FeedCreationError['kind'],
  code: string,
  retryable: boolean,
  nextAction: FeedNextAction,
  retryAction: FeedRetryAction,
  message: string,
  status?: number
): FeedCreationError {
  return {
    kind,
    code,
    retryable,
    nextAction,
    retryAction,
    message,
    ...(typeof status === 'number' ? { status } : {}),
  };
}

function buildLocalError(
  message: string,
  kind: FeedCreationError['kind'],
  nextAction: FeedNextAction
): FeedCreationError {
  const retryable = nextAction === 'retry';
  return buildStructuredError(
    kind,
    localErrorCode(kind, nextAction),
    retryable,
    nextAction,
    retryable ? 'primary' : 'none',
    message
  );
}

function buildPreviewWarning(
  code: string,
  message: string,
  retryable: boolean,
  nextAction: FeedNextAction
): FeedPreviewWarning {
  return { code, message, retryable, nextAction };
}

function normalizeFeedRecord(raw?: RawFeedRecord): FeedRecord | undefined {
  if (!raw) return undefined;

  const feedToken = normalizeString(raw.feed_token);
  const publicUrl = normalizeString(raw.public_url);
  const jsonPublicUrl = normalizeString(raw.json_public_url);
  const url = normalizeString(raw.url);

  if (!feedToken || !publicUrl || !jsonPublicUrl || !url) return undefined;

  return {
    id: normalizeString(raw.id) || feedToken,
    name: normalizeString(raw.name) || url,
    url,
    feed_token: feedToken,
    public_url: publicUrl,
    json_public_url: jsonPublicUrl,
    created_at: normalizeString(raw.created_at) || new Date().toISOString(),
    updated_at: normalizeString(raw.updated_at) || new Date().toISOString(),
  };
}

function normalizeNextAction(
  value: unknown,
  kind: FeedCreationError['kind'],
  retryable: boolean
): FeedNextAction {
  if (
    value === 'enter_token' ||
    value === 'correct_input' ||
    value === 'retry' ||
    value === 'wait' ||
    value === 'none'
  ) {
    return value;
  }

  if (kind === 'auth') return 'enter_token';
  if (kind === 'input') return 'correct_input';
  if (retryable) return 'retry';
  return 'none';
}

function normalizeRetryAction(
  value: unknown,
  nextAction: FeedNextAction,
  retryable: boolean
): FeedRetryAction {
  if (value === 'alternate' || value === 'primary' || value === 'none') {
    return value;
  }

  if (!retryable || nextAction !== 'retry') return 'none';
  return 'primary';
}

function normalizeErrorKind(value: unknown, status: number): FeedCreationError['kind'] {
  if (value === 'auth' || value === 'input' || value === 'network' || value === 'server') return value;

  if (status === 401 || status === 403) return 'auth';
  if (status === 400 || status === 404 || status === 422) return 'input';
  if (isTransientHttpStatus(status)) return 'network';
  return 'server';
}

function defaultRetryableFromStatus(status: number, kind: FeedCreationError['kind']): boolean {
  if (kind === 'auth' || kind === 'input') return false;
  if (kind === 'network') return true;
  return isTransientHttpStatus(status) || status >= 500;
}

function fallbackErrorCode(status: number, kind: FeedCreationError['kind']): string {
  if (status === 401) return 'AUTH_REQUIRED';
  if (status === 403) return 'AUTH_FORBIDDEN';
  if (status === 400) return 'INVALID_INPUT';
  if (status === 404) return 'NOT_FOUND';
  if (status === 422) return 'UNPROCESSABLE_INPUT';
  if (isTransientHttpStatus(status)) return 'TRANSIENT_ERROR';
  if (status >= 500) return 'SERVER_ERROR';
  return `${kind.toUpperCase()}_ERROR`;
}

function fallbackErrorMessage(
  status: number,
  kind: FeedCreationError['kind'],
  nextAction: FeedNextAction
): string {
  if (kind === 'auth') return 'Access token is required.';
  if (kind === 'input') return 'Check the URL and try again.';
  if (nextAction === 'wait') return 'The server is still processing the request.';
  if (isTransientHttpStatus(status) || kind === 'network') return 'Unable to reach the server. Try again.';
  return 'Unable to complete feed creation.';
}

function localErrorCode(kind: FeedCreationError['kind'], nextAction: FeedNextAction): string {
  if (kind === 'auth') return 'AUTH_REQUIRED';
  if (kind === 'input' && nextAction === 'correct_input') return 'INVALID_INPUT';
  return 'LOCAL_VALIDATION_ERROR';
}

function isFeedCreationError(value: unknown): value is FeedCreationError {
  if (!value || typeof value !== 'object') return false;

  const candidate = value as Partial<FeedCreationError>;
  return (
    (candidate.kind === 'auth' ||
      candidate.kind === 'input' ||
      candidate.kind === 'network' ||
      candidate.kind === 'server') &&
    typeof candidate.code === 'string' &&
    typeof candidate.retryable === 'boolean' &&
    typeof candidate.nextAction === 'string' &&
    typeof candidate.retryAction === 'string' &&
    typeof candidate.message === 'string'
  );
}

function isErrorEnvelope(value: unknown): value is RawErrorEnvelope {
  if (!value || typeof value !== 'object') return false;

  const candidate = value as RawErrorEnvelope;
  return (
    candidate.kind !== undefined ||
    candidate.code !== undefined ||
    candidate.retryable !== undefined ||
    candidate.next_action !== undefined ||
    candidate.retry_action !== undefined ||
    candidate.message !== undefined
  );
}

function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

function normalizeString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

async function readJsonResponse<T>(response: Response): Promise<T | undefined> {
  const bodyText = await response.text();
  if (!bodyText.trim()) return undefined;

  try {
    return JSON.parse(bodyText) as T;
  } catch {
    return undefined;
  }
}

function resolveApiUrl(path: string): string {
  return `/api/v1/${path.replace(/^\/+/, '')}`;
}

function resolveFetchUrl(url: string): string {
  if (/^https?:\/\//i.test(url)) return url;
  const origin = globalThis.location?.origin ?? 'http://localhost';
  return new URL(url, origin).toString();
}

function buildCreateHeaders(token: string): HeadersInit {
  const normalizedToken = token.trim();
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };

  if (normalizedToken) {
    headers.Authorization = `Bearer ${normalizedToken}`;
  }

  return headers;
}

function isTransientHttpStatus(status: number): boolean {
  return (
    status === 408 ||
    status === 409 ||
    status === 425 ||
    status === 429 ||
    status === 500 ||
    status === 502 ||
    status === 503 ||
    status === 504
  );
}

function isAbortError(error: unknown): boolean {
  return (
    (error instanceof DOMException && error.name === 'AbortError') ||
    (error instanceof Error && error.name === 'AbortError')
  );
}

function isValidHttpUrl(value: string): boolean {
  try {
    const parsedUrl = new URL(value);
    return parsedUrl.protocol === 'http:' || parsedUrl.protocol === 'https:';
  } catch {
    return false;
  }
}

async function wait(delayMs: number, signal?: AbortSignal): Promise<void> {
  if (delayMs <= 0) return;

  await new Promise<void>((resolve, reject) => {
    const timeoutHandle = globalThis.setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, delayMs);

    const onAbort = () => {
      globalThis.clearTimeout(timeoutHandle);
      reject(new DOMException('Aborted', 'AbortError'));
    };

    if (signal) {
      if (signal.aborted) {
        globalThis.clearTimeout(timeoutHandle);
        reject(new DOMException('Aborted', 'AbortError'));
        return;
      }

      signal.addEventListener('abort', onAbort, { once: true });
    }
  });
}

function normalizePreviewItems(items: unknown[] | undefined): FeedPreviewItem[] {
  if (!Array.isArray(items)) return [];

  return items
    .map((item) => normalizePreviewItem(item))
    .filter((item): item is FeedPreviewItem => item !== undefined)
    .slice(0, 5);
}

function normalizePreviewItem(value: unknown): FeedPreviewItem | undefined {
  if (!value || typeof value !== 'object') return undefined;

  const candidate = value as {
    title?: unknown;
    excerpt?: unknown;
    description?: unknown;
    content_text?: unknown;
    contentText?: unknown;
    published_label?: unknown;
    publishedLabel?: unknown;
    date_published?: unknown;
    datePublished?: unknown;
    date_modified?: unknown;
    dateModified?: unknown;
    url?: unknown;
  };

  const title = normalizeString(candidate.title);
  if (!title) return undefined;

  const url = normalizeString(candidate.url);

  return {
    title,
    excerpt:
      normalizeString(
        candidate.excerpt ?? candidate.description ?? candidate.content_text ?? candidate.contentText
      ) || '',
    publishedLabel:
      normalizeString(
        candidate.published_label ??
          candidate.publishedLabel ??
          candidate.date_published ??
          candidate.datePublished ??
          candidate.date_modified ??
          candidate.dateModified
      ) || '',
    ...(url ? { url } : {}),
  };
}
