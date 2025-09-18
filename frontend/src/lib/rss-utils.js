// RSS utility functions for handling feed display and formatting

export function loadRSSContent(feedUrl, iframe) {
  // Simply set the iframe source to the feed URL directly
  // The browser will handle the RSS content display
  iframe.src = feedUrl;
}

export async function loadRawXML(feedUrl, rssContentEl) {
  try {
    const response = await fetch(feedUrl);
    const rssContent = await response.text();

    // Simple XML display with basic formatting
    const formattedXml = rssContent
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&');

    rssContentEl.textContent = formattedXml;
  } catch (error) {
    rssContentEl.innerHTML = `<div class="content-preview-error">Error loading raw XML: ${error.message}</div>`;
  }
}
