<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:fh="http://purl.org/syndication/history/1.0">
<xsl:output method="xml"/>
<xsl:template match="/">
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="utf-8"/>
  <meta content="no-referrer" name="referrer"/>
  <meta content="width=device-width,initial-scale=1" name="viewport"/>
  <title><xsl:value-of select="rss/channel/title"/> (Feed)</title>
  <link href="/feed.svg" rel="icon"/>
  <link href="/water.css" rel="stylesheet"/>
  <link href="/styles.css" rel="stylesheet"/>
</head>
<body>
  <header>
    <h1>
      <xsl:value-of select="rss/channel/title"/>
    </h1>
  </header>
  <aside>
    <p>
      This is a
      <a href="https://en.wikipedia.org/wiki/RSS" target="_blank" rel="noopener"> syndication feed (also known as <em>RSS</em>)</a>.
      <br/>
      You can follow this feed to get updates through a
      <a href="https://en.wikipedia.org/wiki/News_aggregator" target="_blank" rel="noopener">news aggregator</a> of your choice.
    </p>
  </aside>
  <aside class="aside-icon">
    <a href="https://html2rss.github.io/">
      <img src="/favicon.ico" alt="HTML2RSS icon" />
    </a>
  </aside>
  <main>
    <p>
      <label for="url">
        <img src="/feed.svg" height="16" width="16" alt="the orange RSS icon" role="presentation"/>
        Feed URL
      </label>
      <input id="url" type="text"/>
    </p>

    <h2>Feed content preview</h2>
    <ol class="items">
      <xsl:for-each select="rss/channel/item">
        <li>
          <h3>
            <a rel="noopener">
              <xsl:attribute name="href"><xsl:value-of select="link"/></xsl:attribute>
              <xsl:value-of select="title"/>
            </a>
          </h3>
          <div>
            <xsl:value-of select="description" disable-output-escaping="yes"/>
          </div>
        </li>
      </xsl:for-each>
    </ol>
  </main>
  <footer>
    <p>
      This feed was generated by
      <code>
        <a href="https://html2rss.github.io/"><xsl:value-of select="rss/channel/generator" /></a>
      </code>.
    </p>
  </footer>
  <script type="text/javascript" src="/rss.js" defer="true" />
</body>
</html>
</xsl:template>
</xsl:stylesheet>
