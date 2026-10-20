import { COPY } from '../journey/copy';

export function IosShortcut({
  expanded = false,
  onClick,
}: {
  expanded?: boolean;
  onClick?: (event: Event) => void;
}) {
  return (
    <a
      id="ios-shortcut"
      class="utility-link"
      href="#ios-shortcut-help"
      title={COPY.iosShortcutTitle}
      aria-expanded={expanded ? 'true' : 'false'}
      onClick={(event) => {
        event.preventDefault();
        onClick?.(event);
      }}
    >
      {COPY.iosShortcutTitle}
    </a>
  );
}
