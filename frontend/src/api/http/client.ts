export type HttpEnvelope = {
  readonly ok: boolean;
  readonly status: number;
  readonly body: unknown;
};

type SdkFields = {
  data?: unknown;
  error?: unknown;
  response?: Response;
};

/** True when `error` is an AbortError (DOMException or Error). Neutral HTTP-boundary helper. */
export function isAbortError(error: unknown): boolean {
  return (
    (error instanceof DOMException && error.name === 'AbortError') ||
    (error instanceof Error && error.name === 'AbortError')
  );
}

/** Same-origin JSON API prefix. Absolute when `location.origin` exists so `Request` can parse it. */
export function jsonBaseUrl(): string {
  const origin = globalThis.location?.origin;
  return origin ? `${origin}/api/v1` : '/api/v1';
}

/**
 * Maps Hey API `{ data, error, response }` into a closed `{ ok, status, body }` envelope.
 * Network failures and missing responses are `ok: false` with status `0`.
 */
export async function unwrap(result: Promise<SdkFields>): Promise<HttpEnvelope> {
  try {
    const { data, error, response } = await result;
    if (!response) return { ok: false, status: 0, body: error };

    return {
      ok: response.ok,
      status: response.status,
      body: response.ok ? data : (error ?? data),
    };
  } catch (error) {
    return { ok: false, status: 0, body: error };
  }
}

/** Resolve Hey API's Request/URL fetch argument for host and path checks. */
export function httpRequestUrl(input: RequestInfo | URL): URL {
  if (input instanceof URL) return input;
  if (typeof input === 'string') return new URL(input, location.origin || 'http://localhost');
  return new URL(input.url);
}
