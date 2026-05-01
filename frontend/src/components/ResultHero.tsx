import type { ComponentChildren } from 'preact';

interface ResultHeroProperties {
  title: string;
  body: ComponentChildren;
  actions?: ComponentChildren;
}

export function ResultHero({ title, body, actions }: ResultHeroProperties) {
  return (
    <header
      class="result-hero ui-card ui-card--roomy ui-hero layout-rail-reading layout-stack"
      style={{ '--stack-gap': 'var(--space-3)' }}
    >
      <div class="result-hero__masthead ui-hero__masthead">
        <div class="result-hero__icon-wrap ui-hero__icon-wrap" aria-hidden="true">
          <img class="result-hero__icon ui-hero__icon" src="/feed.svg" alt="" />
        </div>
        <div class="layout-stack layout-stack--tight">
          <h1 class="result-title ui-display-title">{title}</h1>
          {body}
        </div>
      </div>
      <div class="result-hero__actions ui-hero__actions">{actions}</div>
    </header>
  );
}
