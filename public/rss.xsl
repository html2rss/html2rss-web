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
            --font-family-display: "Iowan Old Style", "Georgia", serif;
            --font-size-00: 0.8125rem;
            --font-size-0: 0.9375rem;
            --font-size-1: 1rem;
            --radius-md: 0.7rem;
            --bg-page: #050505;
            --bg-page-muted: #090909;
            --surface-1: rgba(255, 255, 255, 0.015);
            --surface-2: rgba(255, 255, 255, 0.03);
            --surface-3: rgba(255, 255, 255, 0.04);
            --border-muted: rgba(255, 255, 255, 0.12);
            --border-subtle: rgba(255, 255, 255, 0.08);
            --border-strong: rgba(255, 255, 255, 0.18);
            --text-strong: #f3f3ef;
            --text-body: rgba(243, 243, 239, 0.88);
            --text-muted: rgba(243, 243, 239, 0.6);
            --text-faint: rgba(243, 243, 239, 0.3);
            --eyebrow-color: rgba(255, 255, 255, 0.72);
            --accent: #f3f3ef;
            --notice-bg: rgba(255, 255, 255, 0.04);
            --shadow-elevated: 0 24px 60px rgba(0, 0, 0, 0.32);
            --rail-shell: 58rem;
            --rail-reading: 44rem;
            --rail-copy: 34rem;
            --section-gap-tight: 1rem;
            --section-gap: 1.5rem;
            --section-gap-loose: 2rem;
          }

          * {
            box-sizing: border-box;
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
            line-height: 1.5;
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
            border: 1px solid var(--border-subtle);
            border-radius: calc(var(--radius-md) + 0.25rem);
            background:
              linear-gradient(180deg, rgba(255, 255, 255, 0.03), rgba(255, 255, 255, 0.015)),
              var(--surface-1);
          }

          .ui-eyebrow {
            margin: 0;
            color: var(--eyebrow-color);
            font-size: var(--font-size-00);
            letter-spacing: 0.1em;
            text-transform: uppercase;
            font-weight: 600;
          }

          .feed-page {
            padding: 1rem 1rem 2rem;
          }

          .brand-lockup {
            display: inline-grid;
            justify-items: center;
            gap: 0.3rem;
            margin-bottom: var(--section-gap);
          }

          .brand-lockup__mark {
            width: 1.7rem;
            height: 1.7rem;
            padding: 0.3rem;
            display: grid;
            gap: 0.18rem;
            border: 1px solid var(--border-muted);
            border-radius: 0.45rem;
          }

          .brand-lockup__mark span {
            display: block;
            background: var(--accent);
          }

          .brand-lockup__mark span:nth-child(1) {
            width: 100%;
            height: 0.22rem;
          }

          .brand-lockup__mark span:nth-child(2) {
            width: 70%;
            height: 0.22rem;
          }

          .brand-lockup__mark span:nth-child(3) {
            width: 46%;
            height: 0.22rem;
          }

          .brand-lockup__wordmark {
            color: var(--text-strong);
            font-family: var(--font-family-display);
            font-size: 0.96rem;
            font-weight: 700;
            letter-spacing: 0.01em;
          }

          .feed-hero {
            padding: 1.3rem;
            border: 1px solid var(--border-muted);
            border-radius: 1rem;
            background:
              linear-gradient(180deg, rgba(255, 255, 255, 0.035), rgba(255, 255, 255, 0.015)),
              var(--surface-1);
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
            gap: 0.7rem;
            padding-top: 0.4rem;
            border-top: 1px solid var(--border-subtle);
          }

          .feed-meta__row {
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
            align-items: baseline;
          }

          .feed-meta__label {
            color: var(--eyebrow-color);
            font-size: var(--font-size-00);
            letter-spacing: 0.08em;
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
            padding: 0.95rem 1rem;
            border: 1px solid var(--border-strong);
            border-radius: 0.85rem;
            background: var(--notice-bg);
          }

          .feed-notice p {
            margin: 0;
          }

          .feed-notice p + p {
            margin-top: 0.45rem;
            color: var(--text-muted);
          }

          .feed-section {
            margin-top: var(--section-gap);
            gap: 0.95rem;
          }

          .feed-section__label {
            letter-spacing: 0.1em;
          }

          .feed-list {
            margin: 0;
            padding: 0;
            list-style: none;
            gap: 0.95rem;
          }

          .feed-card {
            padding: 1rem 1.05rem;
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
            padding: 1rem 1.05rem;
            border: 1px solid var(--border-subtle);
            border-radius: calc(var(--radius-md) + 0.25rem);
            background: var(--surface-1);
            color: var(--text-muted);
          }

          @media (max-width: 47.9375rem) {
            .feed-page {
              padding-inline: 0.8rem;
            }

            .feed-hero {
              width: 100%;
              padding: 1rem;
            }

            .feed-notice,
            .feed-section {
              width: 100%;
            }

            .feed-meta__row {
              display: grid;
              gap: 0.2rem;
            }
          }
        </style>
      </head>
      <body>
        <main class="feed-page layout-shell">
          <div class="brand-lockup" aria-label="html2rss">
            <span class="brand-lockup__mark" aria-hidden="true">
              <span></span>
              <span></span>
              <span></span>
            </span>
            <strong class="brand-lockup__wordmark">html2rss</strong>
          </div>

          <section class="feed-hero layout-rail-reading layout-stack" style="--stack-gap: 0.8rem;">
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

            <div class="feed-meta layout-stack" style="--stack-gap: 0.7rem;">
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
            <section class="feed-notice layout-rail-reading" aria-label="Feed status">
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
                <ul class="feed-list layout-stack" style="--stack-gap: 0.95rem;">
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
                <div class="feed-empty">This feed does not have any items yet.</div>
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
