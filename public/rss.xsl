<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" />
  <xsl:template match="/">
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <title><xsl:value-of select="rss/channel/title" /> (Feed)</title>
        <link href="/feed.svg" rel="icon" />
        <style>
          body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding:
          1rem; }
          .item { border-bottom: 1px solid #eee; padding: 1rem 0; }
          .item h3 { margin: 0 0 0.5rem 0; }
          .item h3 a { color: #2563eb; text-decoration: none; }
          .item h3 a:hover { text-decoration: underline; }
          .description { color: #666; }
        </style>
      </head>
      <body>
        <h1>
          <xsl:value-of select="rss/channel/title" />
        </h1>

        <xsl:for-each select="rss/channel/item">
          <div class="item">
            <h3>
              <xsl:choose>
                <xsl:when test="title and title != ''">
                  <xsl:choose>
                    <xsl:when test="link and link != ''">
                      <a href="{link}" target="_blank">
                        <xsl:value-of select="title" />
                      </a>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="title" />
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:when>
                <xsl:when test="link and link != ''">
                  <a href="{link}" target="_blank">Item</a>
                </xsl:when>
                <xsl:otherwise>Item</xsl:otherwise>
              </xsl:choose>
            </h3>

            <xsl:if test="description and description != ''">
              <div class="description">
                <xsl:value-of select="description" disable-output-escaping="yes" />
              </div>
            </xsl:if>
          </div>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
