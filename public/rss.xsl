<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" />

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <title><xsl:value-of select="rss/channel/title" /> (Feed)</title>
        <link href="/feed.svg" rel="icon" />
        <style>
          :root {
            color-scheme: dark;
            --font-family-ui: "IBM Plex Sans", "Avenir Next", "Segoe UI", sans-serif;
            --font-family-display: "Fraunces", "Iowan Old Style", "Georgia", serif;
            --font-family-mono: "SFMono-Regular", Consolas, "Liberation Mono", monospace;
            --font-size-00: 0.8125rem;
            --font-size-0: 0.9375rem;
            --font-size-1: 1rem;
            --font-size-2: 1.125rem;
            --line-height-tight: 1.1;
            --line-height-base: 1.5;
            --space-1: 0.25rem;
            --space-2: 0.5rem;
            --space-3: 0.75rem;
            --space-4: 1rem;
            --space-5: 1.5rem;
            --space-6: 2rem;
            --space-7: 3rem;
            --border-width: 1px;
            --border-default: var(--border-width) solid var(--border-subtle);
            --radius-sm: 0.35rem;
            --radius-md: 0.7rem;
            --radius-lg: 0.95rem;
            --eyebrow-letter-spacing: 0.08em;
            --brand-lockup-gap: 0.3rem;
            --brand-lockup-mark-size: 1.7rem;
            --brand-lockup-mark-padding: 0.3rem;
            --brand-lockup-mark-gap: 0.18rem;
            --brand-lockup-mark-radius: 0.45rem;
            --brand-lockup-line-1-height: 0.22rem;
            --brand-lockup-line-2-width: 70%;
            --brand-lockup-line-3-width: 46%;
            --brand-lockup-wordmark-size: 0.96rem;
            --bg-page: #050505;
            --bg-page-muted: #090909;
            --bg-input: #111111;
            --bg-input-strong: #151515;
            --bg-success: rgba(110, 231, 183, 0.08);
            --bg-danger: rgba(248, 113, 113, 0.1);
            --surface-base: rgba(255, 255, 255, 0.02);
            --surface-elevated: rgba(255, 255, 255, 0.04);
            --border-muted: rgba(255, 255, 255, 0.12);
            --border-subtle: rgba(255, 255, 255, 0.08);
            --border-strong: rgba(255, 255, 255, 0.24);
            --text-strong: #f3f3ef;
            --text-body: rgba(243, 243, 239, 0.9);
            --text-muted: rgba(243, 243, 239, 0.58);
            --text-faint: rgba(243, 243, 239, 0.28);
            --eyebrow-color: rgba(255, 255, 255, 0.72);
            --text-inverse: #050505;
            --accent: #f3f3ef;
            --accent-strong: #ffffff;
            --danger: #fca5a5;
            --success: #9ae6b4;
            --focus-ring: 0 0 0 3px rgba(255, 255, 255, 0.16);
            --shadow-elevated: 0 24px 60px rgba(0, 0, 0, 0.32);
            --page-max-width: 60rem;
            --rail-shell: 58rem;
            --rail-reading: 44rem;
            --rail-copy: 34rem;
            --section-gap-tight: var(--space-4);
            --section-gap: var(--space-5);
            --section-gap-loose: var(--space-6);
            --content-max-width: var(--rail-shell);
            --transition-fast: 140ms ease;
          }

          *,
          *::before,
          *::after {
            box-sizing: border-box;
          }

          html,
          body {
            min-height: 100%;
          }

          html {
            background:
              radial-gradient(circle at top, rgba(255, 255, 255, 0.06), transparent 32%),
              linear-gradient(180deg, #080808 0%, #040404 100%);
          }

          body {
            margin: 0;
            min-width: 20rem;
            color: var(--text-body);
            font-family: var(--font-family-ui);
            font-size: var(--font-size-0);
            line-height: var(--line-height-base);
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
            text-rendering: optimizeLegibility;
            background: transparent;
          }

          a {
            color: var(--accent);
            text-decoration: none;
          }

          a:hover,
          a:focus-visible {
            text-decoration: underline;
            text-underline-offset: 0.16em;
          }

          .layout-shell {
            width: min(100%, var(--rail-shell));
            margin: 0 auto;
          }

          .layout-rail-reading {
            width: min(100%, var(--rail-reading));
            margin: 0 auto;
          }

          .layout-rail-copy {
            max-width: var(--rail-copy);
          }

          .layout-stack {
            display: grid;
            gap: var(--stack-gap, var(--section-gap));
          }

          .layout-stack--tight {
            --stack-gap: var(--section-gap-tight);
          }

          .ui-card {
            border: var(--border-default);
            border-radius: var(--radius-lg);
            background:
              linear-gradient(180deg, rgba(255, 255, 255, 0.03), rgba(255, 255, 255, 0.015)),
              var(--surface-base);
          }

          .ui-card--padded {
            padding: clamp(var(--space-3), 4vw, var(--space-4));
          }

          .ui-card--roomy {
            padding: clamp(var(--space-4), 5vw, var(--space-6));
          }

          .ui-card--notice {
            border-radius: var(--radius-md);
          }

          .ui-eyebrow {
            margin: 0;
            color: var(--eyebrow-color);
            font-size: var(--font-size-00);
            letter-spacing: var(--eyebrow-letter-spacing);
            text-transform: uppercase;
            font-weight: 600;
          }

          .feed-page {
            min-height: 100vh;
            padding:
              clamp(0.85rem, 3vh, 2rem)
              clamp(var(--space-3), 3vw, var(--space-4))
              var(--space-5);
          }

          .feed-page__brand {
            display: grid;
            justify-items: center;
          }

          .brand-lockup {
            display: inline-grid;
            justify-items: center;
            gap: var(--brand-lockup-gap);
            margin-bottom: var(--section-gap);
          }

          .brand-lockup__mark {
            width: var(--brand-lockup-mark-size);
            height: var(--brand-lockup-mark-size);
            padding: var(--brand-lockup-mark-padding);
            display: grid;
            gap: var(--brand-lockup-mark-gap);
            border: var(--border-width) solid var(--border-muted);
            border-radius: var(--brand-lockup-mark-radius);
          }

          .brand-lockup__mark span {
            display: block;
            background: var(--accent);
          }

          .brand-lockup__mark span:nth-child(1) {
            width: 100%;
            height: var(--brand-lockup-line-1-height);
          }

          .brand-lockup__mark span:nth-child(2) {
            width: var(--brand-lockup-line-2-width);
            height: var(--brand-lockup-line-1-height);
          }

          .brand-lockup__mark span:nth-child(3) {
            width: var(--brand-lockup-line-3-width);
            height: var(--brand-lockup-line-1-height);
          }

          .brand-lockup__wordmark {
            color: var(--text-strong);
            font-family: var(--font-family-display);
            font-size: var(--brand-lockup-wordmark-size);
            font-weight: 600;
            letter-spacing: 0.01em;
          }

          .feed-hero {
            --stack-gap: var(--space-3);
            box-shadow: var(--shadow-elevated);
          }

          .feed-title {
            margin: 0;
            color: var(--text-strong);
            font-family: var(--font-family-display);
            font-size: clamp(1.8rem, 4.1vw, 2.7rem);
            line-height: 0.96;
            letter-spacing: -0.03em;
          }

          .feed-description {
            margin: 0;
            color: var(--text-body);
            font-size: var(--font-size-1);
          }

          .feed-meta {
            --stack-gap: var(--space-2);
            padding-top: var(--space-2);
            border-top: 1px solid var(--border-subtle);
          }

          .feed-meta__row {
            display: flex;
            flex-wrap: wrap;
            gap: var(--space-2);
            align-items: baseline;
          }

          .feed-meta__label {
            color: var(--eyebrow-color);
            font-size: var(--font-size-00);
            letter-spacing: var(--eyebrow-letter-spacing);
            text-transform: uppercase;
            font-weight: 600;
          }

          .feed-meta__value,
          .feed-meta__value a {
            color: var(--text-body);
            font-size: var(--font-size-0);
          }

          .feed-notice {
            margin-top: var(--section-gap-tight);
          }

          .feed-notice p {
            margin: 0;
          }

          .feed-notice p + p {
            margin-top: var(--space-2);
            color: var(--text-muted);
          }

          .feed-section {
            margin-top: var(--section-gap);
            gap: var(--space-4);
          }

          .feed-section__label {
            letter-spacing: 0.1em;
          }

          .feed-list {
            --stack-gap: var(--space-4);
            margin: 0;
            padding: 0;
            list-style: none;
          }

          .feed-card {
            padding: clamp(var(--space-3), 3vw, var(--space-4));
          }

          .feed-card__title {
            margin: 0;
            color: var(--text-strong);
            font-family: var(--font-family-display);
            font-size: clamp(1.15rem, 2vw, 1.45rem);
            line-height: 1.08;
          }

          .feed-card__meta {
            margin: 0;
            color: var(--text-muted);
            font-size: var(--font-size-00);
            letter-spacing: 0.06em;
            text-transform: uppercase;
          }

          .feed-card__excerpt {
            margin: 0;
            color: var(--text-body);
            font-size: var(--font-size-0);
          }

          .feed-card__actions {
            margin: 0;
          }

          .feed-card__actions a {
            color: rgba(255, 255, 255, 0.76);
            font-size: var(--font-size-00);
            font-weight: 600;
            letter-spacing: 0.06em;
            text-transform: uppercase;
          }

          .feed-empty {
            color: var(--text-muted);
          }

          @media (max-width: 47.9375rem) {
            .feed-hero {
              padding: var(--space-4);
            }

            .feed-meta__row {
              display: grid;
              gap: var(--space-1);
            }
          }
        </style>
      </head>
      <body>
        <main class="feed-page layout-shell">
          <div class="feed-page__brand">
            <div class="brand-lockup" aria-label="html2rss">
              <span class="brand-lockup__mark" aria-hidden="true">
                <span></span>
                <span></span>
                <span></span>
              </span>
              <strong class="brand-lockup__wordmark">html2rss</strong>
            </div>
          </div>

          <section class="feed-hero ui-card ui-card--notice ui-card--roomy layout-rail-reading layout-stack">
            <h1 class="feed-title">
              <xsl:call-template name="clean-text">
                <xsl:with-param name="text" select="string(rss/channel/title)" />
              </xsl:call-template>
            </h1>

            <xsl:if test="normalize-space(string(rss/channel/description)) != ''">
              <p class="feed-description layout-rail-copy">
                <xsl:call-template name="truncate-text">
                  <xsl:with-param name="text">
                    <xsl:call-template name="clean-text">
                      <xsl:with-param name="text" select="string(rss/channel/description)" />
                    </xsl:call-template>
                  </xsl:with-param>
                  <xsl:with-param name="limit" select="260" />
                </xsl:call-template>
              </p>
            </xsl:if>

            <div class="feed-meta layout-stack">
              <div class="feed-meta__row">
                <span class="feed-meta__label">Items</span>
                <span class="feed-meta__value"><xsl:value-of select="count(rss/channel/item)" /></span>
              </div>

              <xsl:if test="normalize-space(string(rss/channel/lastBuildDate)) != ''">
                <div class="feed-meta__row">
                  <span class="feed-meta__label">Updated</span>
                  <span class="feed-meta__value"><xsl:value-of select="rss/channel/lastBuildDate" /></span>
                </div>
              </xsl:if>

              <xsl:if test="normalize-space(string(rss/channel/link)) != ''">
                <div class="feed-meta__row">
                  <span class="feed-meta__label">Source</span>
                  <span class="feed-meta__value">
                    <a href="{rss/channel/link}" target="_blank" rel="noopener noreferrer">
                      <xsl:value-of select="rss/channel/link" />
                    </a>
                  </span>
                </div>
              </xsl:if>

              <xsl:if test="normalize-space(string(rss/channel/generator)) != ''">
                <div class="feed-meta__row">
                  <span class="feed-meta__label">Generated by</span>
                  <span class="feed-meta__value">
                    <xsl:call-template name="clean-text">
                      <xsl:with-param name="text" select="string(rss/channel/generator)" />
                    </xsl:call-template>
                  </span>
                </div>
              </xsl:if>
            </div>
          </section>

          <xsl:if test="rss/channel/title = 'Error' or rss/channel/item[1]/title = 'Content Extraction Failed'">
            <section class="feed-notice ui-card ui-card--notice ui-card--padded layout-rail-reading" aria-label="Feed status">
              <p>
                <xsl:call-template name="clean-text">
                  <xsl:with-param name="text" select="string(rss/channel/title)" />
                </xsl:call-template>
              </p>
              <p>
                <xsl:call-template name="clean-text">
                  <xsl:with-param name="text" select="string(rss/channel/description)" />
                </xsl:call-template>
              </p>
            </section>
          </xsl:if>

          <section class="feed-section layout-rail-reading layout-stack" aria-label="Feed items">
            <p class="feed-section__label ui-eyebrow">Latest items</p>

            <xsl:choose>
              <xsl:when test="count(rss/channel/item) &gt; 0">
                <ul class="feed-list layout-stack">
                  <xsl:for-each select="rss/channel/item">
                    <li>
                      <article class="feed-card ui-card layout-stack layout-stack--tight">
                        <xsl:variable name="cleanTitle">
                          <xsl:call-template name="clean-text">
                            <xsl:with-param name="text" select="string(title)" />
                          </xsl:call-template>
                        </xsl:variable>
                        <xsl:variable name="cleanDescription">
                          <xsl:call-template name="clean-text">
                            <xsl:with-param name="text" select="string(description)" />
                          </xsl:call-template>
                        </xsl:variable>
                        <xsl:variable name="displayTitle">
                          <xsl:choose>
                            <xsl:when test="normalize-space(string($cleanTitle)) != ''">
                              <xsl:value-of select="$cleanTitle" />
                            </xsl:when>
                            <xsl:when test="normalize-space(string($cleanDescription)) != ''">
                              <xsl:call-template name="truncate-text">
                                <xsl:with-param name="text" select="string($cleanDescription)" />
                                <xsl:with-param name="limit" select="92" />
                              </xsl:call-template>
                            </xsl:when>
                            <xsl:otherwise>Untitled item</xsl:otherwise>
                          </xsl:choose>
                        </xsl:variable>

                        <h2 class="feed-card__title">
                          <xsl:value-of select="$displayTitle" />
                        </h2>

                        <xsl:if test="normalize-space(string(pubDate)) != ''">
                          <p class="feed-card__meta"><xsl:value-of select="pubDate" /></p>
                        </xsl:if>

                        <xsl:if test="normalize-space(string($cleanDescription)) != '' and normalize-space(string($cleanDescription)) != normalize-space(string($displayTitle))">
                          <p class="feed-card__excerpt">
                            <xsl:call-template name="truncate-text">
                              <xsl:with-param name="text" select="string($cleanDescription)" />
                              <xsl:with-param name="limit" select="260" />
                            </xsl:call-template>
                          </p>
                        </xsl:if>

                        <xsl:if test="normalize-space(string(link)) != ''">
                          <p class="feed-card__actions">
                            <a href="{link}" target="_blank" rel="noopener noreferrer">Open original</a>
                          </p>
                        </xsl:if>
                      </article>
                    </li>
                  </xsl:for-each>
                </ul>
              </xsl:when>
              <xsl:otherwise>
                <div class="feed-empty ui-card ui-card--padded">This feed does not have any items yet.</div>
              </xsl:otherwise>
            </xsl:choose>
          </section>
        </main>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="truncate-text">
    <xsl:param name="text" />
    <xsl:param name="limit" select="220" />

    <xsl:choose>
      <xsl:when test="string-length($text) &lt;= $limit">
        <xsl:value-of select="$text" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat(normalize-space(substring($text, 1, $limit)), '...')" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="clean-text">
    <xsl:param name="text" />

    <xsl:variable name="withoutNbsp">
      <xsl:call-template name="replace-string">
        <xsl:with-param name="text" select="$text" />
        <xsl:with-param name="search" select="'&amp;nbsp;'" />
        <xsl:with-param name="replace" select="' '" />
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="withoutTags">
      <xsl:call-template name="strip-tags">
        <xsl:with-param name="text" select="string($withoutNbsp)" />
      </xsl:call-template>
    </xsl:variable>

    <xsl:value-of select="normalize-space(string($withoutTags))" />
  </xsl:template>

  <xsl:template name="strip-tags">
    <xsl:param name="text" />

    <xsl:choose>
      <xsl:when test="contains($text, '&lt;') and contains(substring-after($text, '&lt;'), '&gt;')">
        <xsl:value-of select="substring-before($text, '&lt;')" />
        <xsl:text> </xsl:text>
        <xsl:call-template name="strip-tags">
          <xsl:with-param name="text" select="substring-after($text, '&gt;')" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="replace-string">
    <xsl:param name="text" />
    <xsl:param name="search" />
    <xsl:param name="replace" />

    <xsl:choose>
      <xsl:when test="contains($text, $search)">
        <xsl:value-of select="substring-before($text, $search)" />
        <xsl:value-of select="$replace" />
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text" select="substring-after($text, $search)" />
          <xsl:with-param name="search" select="$search" />
          <xsl:with-param name="replace" select="$replace" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
