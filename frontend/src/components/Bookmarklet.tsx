import { buildBookmarkletHref } from '../routes/bookmarkletHref';
import { COPY } from '../journey/copy';

export function Bookmarklet({ onClick }: { onClick?: (event: Event) => void }) {
  return (
    <a
      id="bookmarklet"
      class="utility-link"
      href={buildBookmarkletHref()}
      title={COPY.bookmarkletDragHint}
      onClick={(event) => {
        onClick?.(event);
      }}
    >
      {COPY.bookmarkletTitle}
    </a>
  );
}
