interface DemoButtonsProps {
  onConvert: (url: string) => void;
}

const DEMO_SITES = [
  {
    url: 'https://github.com/trending',
    name: 'GitHub Trending',
    icon: '⭐',
    description: 'See trending repositories',
  },
  {
    url: 'https://news.ycombinator.com',
    name: 'Hacker News',
    icon: '🔥',
    description: 'Latest tech discussions',
  },
  {
    url: 'https://www.chip.de/testberichte',
    name: 'Hardware Reviews',
    icon: '🇩🇪',
    description: 'German tech reviews',
  },
];

export function DemoButtons({ onConvert }: DemoButtonsProps) {
  const handleDemoClick = async (url: string) => {
    try {
      await onConvert(url);
    } catch (error) {}
  };

  return (
    <div class="demo-examples" role="group" aria-label="Demo website conversions">
      {DEMO_SITES.map((site) => (
        <button
          key={site.url}
          type="button"
          class="demo-button"
          onClick={() => handleDemoClick(site.url)}
          aria-label={`Convert ${site.name} to RSS feed - ${site.description}`}
        >
          <div class="demo-content">
            <span class="demo-icon" aria-hidden="true">
              {site.icon}
            </span>
            <div class="demo-text">
              <div class="demo-name">{site.name}</div>
              <div class="demo-description">{site.description}</div>
            </div>
          </div>
        </button>
      ))}
    </div>
  );
}
