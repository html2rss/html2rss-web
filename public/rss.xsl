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
        <link href="/feed.css" rel="stylesheet" />
        <link href="/feed.svg" rel="icon" />
        <script src="/feed-page.js"></script>
      </head>
      <body>
        <main class="feed-page layout-shell layout-shell-padding layout-stack">
          <div class="feed-page__brand">
            <a href="/" class="brand-lockup" aria-label="html2rss">
              <span class="brand-lockup__mark" aria-hidden="true">
                <span></span>
                <span></span>
                <span></span>
              </span>
              <strong class="brand-lockup__wordmark">html2rss</strong>
            </a>
          </div>

          <section class="feed-hero layout-rail-reading layout-stack">
            <p class="ui-eyebrow">RSS feed</p>

            <div class="ui-headline-row">
              <h1 class="ui-display-title">
                <xsl:call-template name="clean-text">
                  <xsl:with-param name="text" select="string(rss/channel/title)" />
                </xsl:call-template>
              </h1>
              <img class="feed-hero__icon" src="/feed.svg" alt="" aria-hidden="true" />
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
              <p class="ui-eyebrow">
                <xsl:choose>
                  <xsl:when test="normalize-space(string(rss/channel/lastBuildDate)) != ''">
                    <span>Updated </span>
                    <time><xsl:value-of select="rss/channel/lastBuildDate" /></time>
                  </xsl:when>
                  <xsl:when test="normalize-space(string(rss/channel/pubDate)) != ''">
                    <span>Published </span>
                    <time><xsl:value-of select="rss/channel/pubDate" /></time>
                  </xsl:when>
                  <xsl:otherwise>
                    <span>Latest item </span>
                    <time><xsl:value-of select="rss/channel/item[1]/pubDate" /></time>
                  </xsl:otherwise>
                </xsl:choose>
              </p>
            </xsl:if>

            <div class="ui-actions layout-rail-reading">
              <a class="btn btn--ghost feed-hero__action--primary" data-feed-reader-link="true" href="#">Open in feed reader</a>
              <button type="button" class="btn btn--ghost" data-copy-feed-url="true">Copy feed URL</button>
              <span class="ui-eyebrow ui-eyebrow--ghost" data-copy-feed-url-status="true" aria-live="polite"></span>
              <a class="btn btn--ghost" data-json-feed-link="true" target="_blank" rel="noopener noreferrer" href="#">Open JSON Feed</a>
              <xsl:if test="normalize-space(string(rss/channel/link)) != ''">
                <a class="btn btn--ghost" href="{rss/channel/link}" target="_blank" rel="noopener noreferrer">Open source site</a>
              </xsl:if>
            </div>
          </section>

          <xsl:if test="rss/channel/title = 'Error' or contains(rss/channel/title, 'Content Extraction Issue') or rss/channel/item[1]/title = 'Content Extraction Failed' or rss/channel/item[1]/title = 'Preview unavailable for this source'">
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

          <section class="feed-section layout-rail-reading layout-stack layout-section-divided" aria-label="Feed items">
            <p class="ui-eyebrow">
              <xsl:value-of select="count(rss/channel/item)" />
              <xsl:text> items</xsl:text>
            </p>

            <xsl:choose>
              <xsl:when test="count(rss/channel/item) &gt; 0">
                <ul class="ui-item-list" role="list">
                  <xsl:for-each select="rss/channel/item">
                    <li class="ui-item">
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
                              <xsl:with-param name="limit" select="72" />
                            </xsl:call-template>
                          </xsl:when>
                          <xsl:otherwise>Untitled item</xsl:otherwise>
                        </xsl:choose>
                      </xsl:variable>
                      <xsl:variable name="hasSummary" select="normalize-space(string($cleanTitle)) != '' and normalize-space(string($cleanDescription)) != '' and normalize-space(string($cleanDescription)) != normalize-space(string($displayTitle))" />

                      <xsl:if test="normalize-space(string(pubDate)) != ''">
                        <p class="ui-item__meta">
                          <time><xsl:value-of select="pubDate" /></time>
                        </p>
                      </xsl:if>

                      <h2 class="ui-item__title">
                        <xsl:choose>
                          <xsl:when test="normalize-space(string(link)) != ''">
                            <a href="{link}" target="_blank" rel="noopener noreferrer">
                              <xsl:value-of select="$displayTitle" />
                            </a>
                          </xsl:when>
                          <xsl:otherwise>
                            <xsl:value-of select="$displayTitle" />
                          </xsl:otherwise>
                        </xsl:choose>
                      </h2>

                      <xsl:if test="$hasSummary">
                        <p class="ui-item__excerpt">
                          <xsl:call-template name="truncate-text">
                            <xsl:with-param name="text" select="string($cleanDescription)" />
                            <xsl:with-param name="limit" select="96" />
                          </xsl:call-template>
                        </p>
                      </xsl:if>
                    </li>
                  </xsl:for-each>
                </ul>
              </xsl:when>
              <xsl:otherwise>
                <div class="feed-empty ui-card ui-card--padded">This feed does not have any items yet.</div>
              </xsl:otherwise>
            </xsl:choose>
          </section>

          <div class="feed-meta layout-rail-reading layout-stack layout-section-divided">
            <xsl:if test="normalize-space(string(rss/channel/link)) != ''">
              <div class="feed-meta__row">
                <span class="ui-eyebrow">Source</span>
                <span class="feed-meta__value">
                  <a href="{rss/channel/link}" target="_blank" rel="noopener noreferrer">
                    <xsl:value-of select="rss/channel/link" />
                  </a>
                </span>
              </div>
            </xsl:if>

            <xsl:if test="normalize-space(string(rss/channel/generator)) != ''">
              <div class="feed-meta__row">
                <span class="ui-eyebrow">Generated by</span>
                <span class="feed-meta__value">
                  <xsl:call-template name="clean-text">
                    <xsl:with-param name="text" select="string(rss/channel/generator)" />
                  </xsl:call-template>
                </span>
              </div>
            </xsl:if>
          </div>
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
