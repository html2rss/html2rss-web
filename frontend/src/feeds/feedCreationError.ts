import type { FeedCreationError, FeedNextAction, FeedRetryAction } from '../api/contracts';
import { isTransientHttpStatus, normalizeBoolean, normalizeString } from './shared';

export interface RawErrorEnvelope {
  kind?: unknown;
  code?: unknown;
  retryable?: unknown;
  next_action?: unknown;
  retry_action?: unknown;
  message?: unknown;
}

export interface RawApiResponse {
  success?: unknown;
  data?: unknown;
  error?: unknown;
}

export function normalizeFeedCreationError(error: unknown): FeedCreationError {
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

export function normalizeFeedCreationErrorFromResponse(
  status: number,
  errorPayload: unknown,
  payload?: RawApiResponse
): FeedCreationError {
  const envelope = resolveErrorEnvelope(errorPayload, payload);

  const kind = normalizeErrorKind(envelope?.kind, status);
  const isRetryable = normalizeBoolean(envelope?.retryable, defaultRetryableFromStatus(status, kind));
  const nextAction = normalizeNextAction(envelope?.next_action, kind, isRetryable);
  const retryAction = normalizeRetryAction(envelope?.retry_action, nextAction, isRetryable);
  const code = normalizeString(envelope?.code) || fallbackErrorCode(status, kind);
  const message = normalizeString(envelope?.message) || fallbackErrorMessage(status, kind, nextAction);

  return buildStructuredError(kind, code, isRetryable, nextAction, retryAction, message, status);
}

export function buildStructuredError(
  kind: FeedCreationError['kind'],
  code: string,
  // eslint-disable-next-line unicorn/consistent-boolean-name
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
    ...(typeof status === 'number' && { status }),
  };
}

export function buildLocalError(
  message: string,
  kind: FeedCreationError['kind'],
  nextAction: FeedNextAction
): FeedCreationError {
  const isRetryable = nextAction === 'retry';
  return buildStructuredError(
    kind,
    localErrorCode(kind, nextAction),
    isRetryable,
    nextAction,
    isRetryable ? 'primary' : 'none',
    message
  );
}

function resolveErrorEnvelope(errorPayload: unknown, payload?: RawApiResponse): RawErrorEnvelope | undefined {
  if (isErrorEnvelope(errorPayload)) return errorPayload;
  if (isErrorEnvelope(payload?.error)) return payload.error;
  if (isErrorEnvelope(payload)) return payload;
  return undefined;
}

function normalizeNextAction(
  value: unknown,
  kind: FeedCreationError['kind'],
  // eslint-disable-next-line unicorn/consistent-boolean-name
  retryable: boolean
): FeedNextAction {
  if ((['enter_token', 'correct_input', 'retry', 'wait', 'none'] as unknown[]).includes(value)) {
    return value as FeedNextAction;
  }

  if (kind === 'auth') return 'enter_token';
  if (kind === 'input') return 'correct_input';
  if (retryable) return 'retry';
  return 'none';
}

function normalizeRetryAction(
  value: unknown,
  nextAction: FeedNextAction,
  // eslint-disable-next-line unicorn/consistent-boolean-name
  retryable: boolean
): FeedRetryAction {
  if ((['alternate', 'primary', 'none'] as unknown[]).includes(value)) {
    return value as FeedRetryAction;
  }

  if (!retryable || nextAction !== 'retry') return 'none';
  return 'primary';
}

function normalizeErrorKind(value: unknown, status: number): FeedCreationError['kind'] {
  if ((['auth', 'input', 'network', 'server'] as unknown[]).includes(value))
    return value as FeedCreationError['kind'];

  if (status === 401 || status === 403) return 'auth';
  if ([400, 404, 422].includes(status)) return 'input';
  if (isTransientHttpStatus(status)) return 'network';
  return 'server';
}

// eslint-disable-next-line unicorn/consistent-boolean-name
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
    (['auth', 'input', 'network', 'server'] as unknown[]).includes(candidate.kind) &&
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
