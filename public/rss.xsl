<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" />

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <title><xsl:value-of select="rss/channel/title" /> (Feed)</title>
        <link href="/shared-ui.css" rel="stylesheet" />
        <link href="/feed.svg" rel="icon" />
        <style>
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
            margin-bottom: var(--section-gap);
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
