<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:atom="http://www.w3.org/2005/Atom">
  <xsl:output method="html" />

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <title><xsl:value-of select="rss/channel/title" /> (Feed)</title>
        <link href="/shared-ui.css" rel="stylesheet" />
        <link href="/feed.svg" rel="icon" />
        <script src="/feed-reader-link.js"></script>
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
          }

          .feed-hero__body {
            display: grid;
            gap: var(--space-3);
          }

          .feed-hero__masthead {
            width: auto;
            display: flex;
            align-items: baseline;
            gap: var(--space-3);
          }

          .feed-hero__icon-wrap {
            width: clamp(1.8rem, 4vw, 2.5rem);
            height: clamp(1.8rem, 4vw, 2.5rem);
            display: inline-flex;
            align-items: center;
            justify-content: center;
            flex: 0 0 auto;
            transform: translateY(0.08em);
          }

          .feed-hero__icon {
            width: 100%;
            height: 100%;
            opacity: 0.92;
          }

          .feed-title {
            flex: 1 1 auto;
          }

          .feed-hero__lede {
            margin: 0;
            color: var(--text-muted);
            font-size: var(--font-size-1);
            max-width: 32rem;
          }

          .feed-hero__action--primary {
            border-color: var(--border-reader-strong);
            background: var(--surface-reader-strong);
          }

          .feed-hero__stamp {
            margin: 0;
            color: var(--text-muted);
            font-size: var(--font-size-00);
            letter-spacing: var(--eyebrow-letter-spacing);
            text-transform: uppercase;
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
            color: var(--text-soft);
            font-size: var(--font-size-00);
            font-weight: 600;
            letter-spacing: 0.06em;
            text-transform: uppercase;
          }

          .feed-card__footer {
            display: flex;
            flex-wrap: wrap;
            gap: var(--space-3);
            align-items: center;
            justify-content: space-between;
          }

          .feed-card__signals {
            display: flex;
            flex-wrap: wrap;
            gap: 0.45rem;
            align-items: center;
            justify-content: flex-end;
            margin-left: auto;
          }

          .feed-signal {
            display: inline-flex;
            align-items: center;
            gap: 0.38rem;
            padding: 0.34rem 0.58rem;
            border-radius: 999px;
            border: 1px solid var(--border-chip);
            background: var(--surface-chip);
            color: var(--text-muted);
            font-size: 0.72rem;
            letter-spacing: 0.07em;
            text-transform: uppercase;
            white-space: nowrap;
          }

          .feed-signal__glyph {
            width: 0.42rem;
            height: 0.42rem;
            border-radius: 999px;
            background: currentColor;
            opacity: 0.76;
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

            .feed-card__footer {
              align-items: start;
            }

            .feed-card__signals {
              width: 100%;
              justify-content: flex-start;
              margin-left: 0;
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

          <section class="feed-hero ui-card ui-card--notice ui-card--roomy ui-hero layout-rail-reading layout-stack">
            <div class="feed-hero__body">
              <div class="feed-hero__masthead ui-hero__masthead">
                <div class="feed-hero__icon-wrap ui-hero__icon-wrap" aria-hidden="true">
                  <img class="feed-hero__icon ui-hero__icon" src="/feed.svg" alt="" />
                </div>
                <h1 class="feed-title ui-display-title">
                  <xsl:call-template name="clean-text">
                    <xsl:with-param name="text" select="string(rss/channel/title)" />
                  </xsl:call-template>
                </h1>
              </div>

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

              <xsl:if test="normalize-space(string(rss/channel/lastBuildDate)) != '' or normalize-space(string(rss/channel/pubDate)) != '' or normalize-space(string(rss/channel/item[1]/pubDate)) != ''">
                <p class="feed-hero__stamp">
                  <xsl:choose>
                    <xsl:when test="normalize-space(string(rss/channel/lastBuildDate)) != ''">
                      <span>Updated </span>
                      <xsl:value-of select="rss/channel/lastBuildDate" />
                    </xsl:when>
                    <xsl:when test="normalize-space(string(rss/channel/pubDate)) != ''">
                      <span>Published </span>
                      <xsl:value-of select="rss/channel/pubDate" />
                    </xsl:when>
                    <xsl:otherwise>
                      <span>Latest item </span>
                      <xsl:value-of select="rss/channel/item[1]/pubDate" />
                    </xsl:otherwise>
                  </xsl:choose>
                </p>
              </xsl:if>
              <div class="feed-hero__actions ui-hero__actions">
                <a class="feed-hero__action btn btn--ghost feed-hero__action--primary" data-feed-reader-link="true">
                  <xsl:attribute name="href">
                    <xsl:choose>
                      <xsl:when test="normalize-space(string(rss/channel/atom:link[@rel='self']/@href)) != ''">
                        <xsl:text>feed:</xsl:text>
                        <xsl:value-of select="rss/channel/atom:link[@rel='self']/@href" />
                      </xsl:when>
                      <xsl:otherwise>#</xsl:otherwise>
                    </xsl:choose>
                  </xsl:attribute>
                  Open in feed reader
                </a>
                <xsl:if test="normalize-space(string(rss/channel/link)) != ''">
                  <a class="feed-hero__action btn btn--ghost" href="{rss/channel/link}" target="_blank" rel="noopener noreferrer">Open source site</a>
                </xsl:if>
              </div>
            </div>

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
                        <xsl:variable name="hasSummary" select="normalize-space(string($cleanDescription)) != '' and normalize-space(string($cleanDescription)) != normalize-space(string($displayTitle))" />
                        <xsl:variable name="hasImage" select="enclosure[contains(translate(@type, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'image/')] or *[local-name()='thumbnail'] or *[local-name()='content'][contains(translate(@type, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'image/')] or *[local-name()='group']/*[local-name()='content'][contains(translate(@type, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'image/')] or *[local-name()='image'][normalize-space(string(.)) != '']" />
                        <xsl:variable name="hasCategories" select="category[normalize-space(string(.)) != '']" />
                        <xsl:variable name="hasAuthor" select="normalize-space(string(author)) != '' or *[local-name()='creator'][normalize-space(string(.)) != '']" />

                        <h2 class="feed-card__title">
                          <xsl:value-of select="$displayTitle" />
                        </h2>

                        <xsl:if test="normalize-space(string(pubDate)) != ''">
                          <p class="feed-card__meta"><xsl:value-of select="pubDate" /></p>
                        </xsl:if>

                        <xsl:if test="$hasSummary">
                          <p class="feed-card__excerpt">
                            <xsl:call-template name="truncate-text">
                              <xsl:with-param name="text" select="string($cleanDescription)" />
                              <xsl:with-param name="limit" select="260" />
                            </xsl:call-template>
                          </p>
                        </xsl:if>

                        <xsl:if test="normalize-space(string(link)) != '' or $hasSummary or $hasImage or $hasCategories or $hasAuthor">
                          <div class="feed-card__footer">
                            <xsl:if test="normalize-space(string(link)) != ''">
                              <p class="feed-card__actions">
                                <a href="{link}" target="_blank" rel="noopener noreferrer">Open original</a>
                              </p>
                            </xsl:if>

                            <xsl:if test="$hasSummary or $hasImage or $hasCategories or $hasAuthor">
                              <div class="feed-card__signals" aria-label="Item quality indicators">
                                <xsl:if test="$hasSummary">
                                  <span class="feed-signal"><span class="feed-signal__glyph"></span><span>Summary</span></span>
                                </xsl:if>
                                <xsl:if test="$hasImage">
                                  <span class="feed-signal"><span class="feed-signal__glyph"></span><span>Image</span></span>
                                </xsl:if>
                                <xsl:if test="$hasCategories">
                                  <span class="feed-signal"><span class="feed-signal__glyph"></span><span>Tags</span></span>
                                </xsl:if>
                                <xsl:if test="$hasAuthor">
                                  <span class="feed-signal"><span class="feed-signal__glyph"></span><span>Byline</span></span>
                                </xsl:if>
                              </div>
                            </xsl:if>
                          </div>
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

    <xsl:variable name="decodedLt">
      <xsl:call-template name="replace-string">
        <xsl:with-param name="text" select="string($withoutTags)" />
        <xsl:with-param name="search" select="'&amp;lt;'" />
        <xsl:with-param name="replace" select="'&lt;'" />
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="decodedText">
      <xsl:call-template name="replace-string">
        <xsl:with-param name="text" select="string($decodedLt)" />
        <xsl:with-param name="search" select="'&amp;gt;'" />
        <xsl:with-param name="replace" select="'&gt;'" />
      </xsl:call-template>
    </xsl:variable>

    <xsl:value-of select="normalize-space(string($decodedText))" />
  </xsl:template>

  <xsl:template name="strip-tags">
    <xsl:param name="text" />

    <xsl:variable name="beforeLt" select="substring-before($text, '&lt;')" />
    <xsl:variable name="afterLt" select="substring-after($text, '&lt;')" />
    <xsl:variable name="tagLead" select="substring($afterLt, 1, 1)" />

    <xsl:choose>
      <xsl:when test="contains($text, '&lt;')">
        <xsl:value-of select="$beforeLt" />
        <xsl:choose>
          <xsl:when test="contains($afterLt, '&gt;') and contains('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/!?', $tagLead)">
            <xsl:text> </xsl:text>
            <xsl:call-template name="strip-tags">
              <xsl:with-param name="text" select="substring-after($afterLt, '&gt;')" />
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>&lt;</xsl:text>
            <xsl:call-template name="strip-tags">
              <xsl:with-param name="text" select="$afterLt" />
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
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
