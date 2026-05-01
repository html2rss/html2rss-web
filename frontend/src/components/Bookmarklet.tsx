export function Bookmarklet() {
  const bookmarkletHref = (() => {
    if (globalThis.window === undefined) return '#';

    const targetPrefix = new URL('/#/create?url=', globalThis.location.href).toString();

    return `javascript:window.location.assign(${JSON.stringify(targetPrefix)}+encodeURIComponent(window.location.href));`;
  })();

  return (
    <a
      id="bookmarklet"
      class="utility-link"
      href={bookmarkletHref}
      title="Drag this bookmarklet to your bookmarks bar"
    >
      Bookmarklet
    </a>
  );
}
