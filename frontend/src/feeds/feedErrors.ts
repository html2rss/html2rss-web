import type {
  FeedCreationError,
  FeedCreationErrorCode,
  FeedErrorKind,
  FeedNextAction,
  FeedPreviewWarning,
  FeedRetryAction,
} from '../api/contracts';
import { COPY } from '../journey/copy';
import { normalizeBoolean, normalizeString } from './feedParsers';

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

const STATUS_KINDS: Record<number, FeedErrorKind> = {
  400: 'input',
  401: 'auth',
  403: 'auth',
  404: 'input',
  422: 'input',
  429: 'client',
};

const STATUS_FALLBACK_CODES: Record<number, FeedCreationErrorCode> = {
  400: 'INVALID_INPUT',
  401: 'AUTH_REQUIRED',
  403: 'AUTH_FORBIDDEN',
  404: 'NOT_FOUND',
  422: 'UNPROCESSABLE_INPUT',
};

const DEFAULT_NEXT_ACTIONS: Record<FeedErrorKind, FeedNextAction> = {
  auth: 'enter_token',
  input: 'correct_input',
  network: 'retry',
  server: 'none',
  client: 'none',
};

const DEFAULT_KIND_MESSAGES: Record<FeedErrorKind, string> = {
  auth: COPY.authRequired,
  input: COPY.checkUrlAndRetry,
  network: COPY.unableToReachServer,
  server: COPY.unableToCompleteCreation,
  client: COPY.unableToCompleteCreation,
};

const VALID_KINDS = new Set<FeedErrorKind>(['auth', 'input', 'network', 'server', 'client']);
const VALID_NEXT_ACTIONS = new Set<FeedNextAction>(['enter_token', 'correct_input', 'retry', 'wait', 'none']);
const VALID_RETRY_ACTIONS = new Set<FeedRetryAction>(['alternate', 'primary', 'none']);

export function normalizeFeedCreationError(error: unknown): FeedCreationError {
  if (isFeedCreationError(error)) return error;

  const isError = error instanceof Error;
  const message =
    (isError && error.message) ||
    (isError ? COPY.unableToReachServerShort : COPY.unableToCompleteCreation);
  const kind: FeedErrorKind = isError ? 'network' : 'server';
  const code: FeedCreationErrorCode = isError ? 'NETWORK_ERROR' : 'UNKNOWN_ERROR';

  return buildStructuredError(kind, code, true, 'retry', 'primary', message);
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
  const code = (normalizeString(envelope?.code) as FeedCreationErrorCode) || fallbackErrorCode(status, kind);
  const message = normalizeString(envelope?.message) || fallbackErrorMessage(status, kind, nextAction);

  return buildStructuredError(kind, code, isRetryable, nextAction, retryAction, message, status);
}

export function buildStructuredError(
  kind: FeedErrorKind,
  code: FeedCreationErrorCode,
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
  kind: FeedErrorKind,
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

export function buildPreviewWarning(
  code: FeedCreationErrorCode,
  message: string,
  // eslint-disable-next-line unicorn/consistent-boolean-name
  retryable: boolean,
  nextAction: FeedNextAction
): FeedPreviewWarning {
  return { code, message, retryable, nextAction };
}

export function resolveErrorEnvelope(
  errorPayload: unknown,
  payload?: RawApiResponse
): RawErrorEnvelope | undefined {
  if (isErrorEnvelope(errorPayload)) return errorPayload;
  if (isErrorEnvelope(payload?.error)) return payload.error;
  if (isErrorEnvelope(payload)) return payload;
  return undefined;
}

export function normalizeNextAction(
  value: unknown,
  kind: FeedErrorKind,
  // eslint-disable-next-line unicorn/consistent-boolean-name
  retryable: boolean
): FeedNextAction {
  if (typeof value === 'string' && VALID_NEXT_ACTIONS.has(value as FeedNextAction)) {
    return value as FeedNextAction;
  }
  if (kind === 'auth' || kind === 'input') return DEFAULT_NEXT_ACTIONS[kind];
  return retryable ? 'retry' : 'none';
}

export function normalizeRetryAction(
  value: unknown,
  nextAction: FeedNextAction,
  // eslint-disable-next-line unicorn/consistent-boolean-name
  retryable: boolean
): FeedRetryAction {
  if (typeof value === 'string' && VALID_RETRY_ACTIONS.has(value as FeedRetryAction)) {
    return value as FeedRetryAction;
  }
  return retryable && nextAction === 'retry' ? 'primary' : 'none';
}

export function normalizeErrorKind(value: unknown, status: number): FeedErrorKind {
  if (typeof value === 'string' && VALID_KINDS.has(value as FeedErrorKind)) {
    return value as FeedErrorKind;
  }
  return STATUS_KINDS[status] || (isTransientStatus(status) ? 'network' : 'server');
}

// eslint-disable-next-line unicorn/consistent-boolean-name
export function defaultRetryableFromStatus(status: number, kind: FeedErrorKind): boolean {
  if (kind === 'auth' || kind === 'input') return false;
  if (kind === 'network' || kind === 'client') return true;
  return isTransientStatus(status) || status >= 500;
}

export function fallbackErrorCode(status: number, kind: FeedErrorKind): FeedCreationErrorCode {
  const mapped = STATUS_FALLBACK_CODES[status];
  if (mapped) return mapped;
  if (isTransientStatus(status)) return 'TRANSIENT_ERROR';
  if (status >= 500) return 'SERVER_ERROR';
  return `${kind.toUpperCase()}_ERROR`;
}

export function fallbackErrorMessage(
  status: number,
  kind: FeedErrorKind,
  nextAction: FeedNextAction
): string {
  if (nextAction === 'wait') return COPY.serverStillProcessing;
  if (isTransientStatus(status) || kind === 'network') return COPY.unableToReachServer;
  return DEFAULT_KIND_MESSAGES[kind];
}

export function localErrorCode(kind: FeedErrorKind, nextAction: FeedNextAction): FeedCreationErrorCode {
  if (kind === 'auth') return 'AUTH_REQUIRED';
  if (kind === 'input' && nextAction === 'correct_input') return 'INVALID_INPUT';
  return 'LOCAL_VALIDATION_ERROR';
}

export function isFeedCreationError(value: unknown): value is FeedCreationError {
  if (!value || typeof value !== 'object') return false;

  const candidate = value as Partial<FeedCreationError>;
  return (
    typeof candidate.kind === 'string' &&
    VALID_KINDS.has(candidate.kind as FeedErrorKind) &&
    typeof candidate.code === 'string' &&
    typeof candidate.retryable === 'boolean' &&
    typeof candidate.nextAction === 'string' &&
    VALID_NEXT_ACTIONS.has(candidate.nextAction as FeedNextAction) &&
    typeof candidate.retryAction === 'string' &&
    VALID_RETRY_ACTIONS.has(candidate.retryAction as FeedRetryAction) &&
    typeof candidate.message === 'string'
  );
}

export function isErrorEnvelope(value: unknown): value is RawErrorEnvelope {
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

function isTransientStatus(status: number): boolean {
  return [408, 409, 425, 429, 500, 502, 503, 504].includes(status);
}
