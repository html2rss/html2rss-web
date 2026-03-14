export function Bookmarklet() {
  const bookmarkletHref = (() => {
    if (typeof window === 'undefined') return '#';

    const baseUrl = new URL(window.location.origin);
    baseUrl.pathname = '/';
    baseUrl.search = '?url=';

    return `javascript:window.location.href='${baseUrl.toString()}'+encodeURIComponent(window.location.href);`;
  })();

  return (
    <div class="bookmarklet-inline" aria-label="Bookmarklet utility">
      <p class="bookmarklet-inline__title">Browser shortcut</p>
      <p>Drag this into your bookmarks bar to send the current page back here.</p>
      <a id="bookmarklet" class="bookmarklet-link" href={bookmarkletHref}>
        Convert page to feed
      </a>
    </div>
  );
}
