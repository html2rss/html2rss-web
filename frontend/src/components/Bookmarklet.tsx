export function Bookmarklet() {
  const bookmarkletHref = (() => {
    if (typeof window === 'undefined') return '#';

    const appUrl = new URL(window.location.href);
    appUrl.search = '';
    appUrl.hash = '';

    const targetPath = appUrl.pathname.endsWith('/frontend/index.html') ? appUrl.pathname : '/';
    const targetPrefix = `${appUrl.origin}${targetPath}?url=`;

    return `javascript:window.location.href=${JSON.stringify(targetPrefix)}+encodeURIComponent(window.location.href);`;
  })();

  return (
    <div class="bookmarklet-inline" aria-label="Bookmarklet utility">
      <p class="bookmarklet-inline__title">Browser shortcut</p>
      <p>Drag this into your bookmarks bar.</p>
      <a id="bookmarklet" class="bookmarklet-link" href={bookmarkletHref}>
        Convert page to feed
      </a>
    </div>
  );
}
