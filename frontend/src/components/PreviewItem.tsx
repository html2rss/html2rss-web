import { useState } from 'preact/hooks';

interface PreviewItemProperties {
  title: string;
  excerpt?: string;
  url?: string;
  publishedLabel?: string;
  imageUrl?: string;
}

export function PreviewItem({ title, excerpt, url, publishedLabel, imageUrl }: PreviewItemProperties) {
  return (
    <>
      {imageUrl ? <SampleImage url={imageUrl} /> : undefined}
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

function SampleImage({ url }: { readonly url: string }) {
  const [visible, setVisible] = useState(true);
  if (!visible) return;

  return (
    <img
      class="studio-sample-image"
      alt=""
      src={url}
      referrerPolicy="no-referrer"
      loading="lazy"
      onError={() => setVisible(false)}
    />
  );
}
