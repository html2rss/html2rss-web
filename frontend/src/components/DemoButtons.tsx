import styles from './DemoButtons.module.css';

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
    <div class="tile-grid" role="group" aria-label="Demo website conversions">
      {DEMO_SITES.map((site) => (
        <button
          key={site.url}
          type="button"
          class={styles.button}
          onClick={() => handleDemoClick(site.url)}
          aria-label={`Convert ${site.name} to RSS feed - ${site.description}`}
        >
          <div class={styles.content}>
            <span class={styles.icon} aria-hidden="true">
              {site.icon}
            </span>
            <span class={styles.text}>
              <span class={styles.name}>{site.name}</span>
              <span class={styles.description}>{site.description}</span>
            </span>
          </div>
        </button>
      ))}
    </div>
  );
}
