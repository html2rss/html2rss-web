import { buildAppRouteHref } from '../routes/appRoute';
import { COPY } from '../journey/copy';

export function Bookmarklet({ onClick }: { onClick?: (event: Event) => void }) {
  const bookmarkletHref = (() => {
    if (globalThis.window === undefined) return '#';

    const createHref = buildAppRouteHref({ kind: 'create' });
    const targetPrefix = `${createHref}?url=`;

    return `javascript:window.location.assign(${JSON.stringify(targetPrefix)}+encodeURIComponent(window.location.href));`;
  })();

  return (
    <a
      id="bookmarklet"
      class="utility-link"
      href={bookmarkletHref}
      title={COPY.bookmarkletDragHint}
      onClick={(event) => {
        onClick?.(event);
      }}
    >
      {COPY.bookmarkletTitle}
    </a>
  );
}
