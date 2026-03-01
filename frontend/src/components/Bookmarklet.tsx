import { useMemo } from 'preact/hooks';

export function Bookmarklet() {
  const bookmarkletHref = useMemo(() => {
    if (typeof window === 'undefined') return '#';

    const baseUrl = new URL(window.location.origin);
    baseUrl.pathname = '/';
    baseUrl.search = '?url=';

    return `javascript:window.location.href='${baseUrl.toString()}'+encodeURIComponent(window.location.href);`;
  }, []);

  return (
    <details class="bookmarklet-inline" aria-label="Bookmarklet utility">
      <summary>Advanced: bookmarklet</summary>
      <p>
        Drag this to your bookmarks bar:
        <a id="bookmarklet" class="bookmarklet-link" href={bookmarkletHref}>
          Convert to RSS
        </a>
      </p>
    </details>
  );
}
