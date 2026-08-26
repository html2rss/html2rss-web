interface PreviewItemProperties {
  title: string;
  excerpt?: string;
  url?: string;
  publishedLabel?: string;
}

export function PreviewItem({ title, excerpt, url, publishedLabel }: PreviewItemProperties) {
  return (
    <>
      {publishedLabel && (
        <p class="ui-item__meta">
          <time>{publishedLabel}</time>
        </p>
      )}
      <h2 class="ui-item__title">
        {url ? (
          <a href={url} target="_blank" rel="noopener noreferrer">
            {title}
          </a>
        ) : (
          title
        )}
      </h2>
      {title && excerpt && <p class="ui-item__excerpt">{excerpt}</p>}
    </>
  );
}
