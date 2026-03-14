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
    <a id="bookmarklet" class="utility-link" href={bookmarkletHref}>
      Bookmarklet
    </a>
  );
}
