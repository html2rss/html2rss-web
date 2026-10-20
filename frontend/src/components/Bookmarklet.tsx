import { buildCreatePrefillPrefix } from '../routes/appRoute';
import { COPY } from '../journey/copy';

export function Bookmarklet({
  expanded = false,
  onClick,
}: {
  expanded?: boolean;
  onClick?: (event: Event) => void;
}) {
  const bookmarkletHref = (() => {
    if (globalThis.window === undefined) return '#';

    const targetPrefix = buildCreatePrefillPrefix();
    return `javascript:window.location.assign(${JSON.stringify(targetPrefix)}+encodeURIComponent(window.location.href));`;
  })();

  return (
    <a
      id="bookmarklet"
      class="utility-link"
      href={bookmarkletHref}
      title={COPY.bookmarkletDragHint}
      aria-expanded={expanded ? 'true' : 'false'}
      onClick={(event) => {
        event.preventDefault();
        onClick?.(event);
      }}
    >
      {COPY.bookmarkletTitle}
    </a>
  );
}
