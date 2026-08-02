export function normalizeString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

// eslint-disable-next-line unicorn/consistent-boolean-name
export function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

export function isTransientHttpStatus(status: number): boolean {
  return [408, 409, 425, 429, 500, 502, 503, 504].includes(status);
}

export function isAbortError(error: unknown): boolean {
  return (
    (error instanceof DOMException && error.name === 'AbortError') ||
    (error instanceof Error && error.name === 'AbortError')
  );
}

export async function wait(delayMs: number, signal?: AbortSignal): Promise<void> {
  if (delayMs <= 0) return;

  await new Promise<void>((resolve, reject) => {
    const timeoutHandle = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, delayMs);

    const onAbort = () => {
      clearTimeout(timeoutHandle);
      reject(new DOMException('Aborted', 'AbortError'));
    };

    if (signal) {
      if (signal.aborted) {
        clearTimeout(timeoutHandle);
        reject(new DOMException('Aborted', 'AbortError'));
        return;
      }

      signal.addEventListener('abort', onAbort, { once: true });
    }
  });
}

export function resolveFetchUrl(url: string): string {
  if (/^https?:\/\//i.test(url)) return url;
  const origin = globalThis.location?.origin ?? 'http://localhost';
  return new URL(url, origin).href;
}

export async function readJsonResponse<T>(response: Response): Promise<T | undefined> {
  const bodyText = await response.text();
  if (!bodyText.trim()) return undefined;

  try {
    return JSON.parse(bodyText) as T;
  } catch {
    return undefined;
  }
}
