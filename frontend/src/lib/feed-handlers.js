// Feed handling functions for RSS display and management

// Import will be handled by the main script

export function fetchAndDisplayRSS(feedUrl) {
  try {
    const xmlFeedDisplay = document.getElementById('xml-feed-display');
    const xmlFeedContent = document.getElementById('xml-feed-content');
    const xmlRawContent = document.getElementById('xml-raw-content');
    const xmlToggle = document.getElementById('xml-toggle');
    const rssIframe = document.getElementById('rss-iframe');
    const rssContentEl = document.getElementById('rss-content');
    const openFeedLink = document.getElementById('open-feed-link');

    if (xmlFeedDisplay) {
      xmlFeedDisplay.classList.remove('hidden');
    }

    // Set the feed URL for the open in new tab link
    if (openFeedLink) {
      openFeedLink.href = feedUrl;
    }

    // Load and display the RSS content directly in iframe
    if (rssIframe) {
      window.loadRSSContent(feedUrl, rssIframe);
    }

    // Set up toggle functionality
    if (xmlToggle) {
      xmlToggle.onclick = () => {
        const isShowingRaw = !xmlRawContent?.classList.contains('hidden');
        if (isShowingRaw) {
          // Switch to styled view
          xmlFeedContent.classList.remove('hidden');
          xmlRawContent.classList.add('hidden');
          xmlToggle.textContent = 'Show Raw XML';
        } else {
          // Switch to raw XML view
          xmlFeedContent.classList.add('hidden');
          xmlRawContent.classList.remove('hidden');
          xmlToggle.textContent = 'Show Styled Preview';

          // Load raw XML content if not already loaded
          if (rssContentEl && !rssContentEl.innerHTML) {
            window.loadRawXML(feedUrl, rssContentEl);
          }
        }
      };
      xmlToggle.textContent = 'Show Raw XML';
    }

    // Auto-show the styled content
    if (xmlFeedContent) {
      xmlFeedContent.classList.remove('hidden');
    }
  } catch (error) {
    const xmlFeedDisplay = document.getElementById('xml-feed-display');
    if (xmlFeedDisplay) {
      xmlFeedDisplay.innerHTML = `<div class="content-preview-error">Error fetching RSS content: ${error.message}</div>`;
      xmlFeedDisplay.classList.remove('hidden');
    }
  }
}

export async function showContentPreview(feedUrl) {
  try {
    const response = await fetch(feedUrl);
    const rssContent = await response.text();

    // Parse RSS content to extract items
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(rssContent, 'text/xml');
    const items = xmlDoc.querySelectorAll('item');

    const xmlPreview = document.getElementById('xml-preview');
    if (!xmlPreview) return;

    if (items.length === 0) {
      // No items found - show warning
      xmlPreview.innerHTML = `
        <div class="content-preview-warning">
          <h4>⚠️ Content Extraction Issue</h4>
          <p>No content could be extracted from this site. This might be due to:</p>
          <ul>
            <li>JavaScript-heavy site (try browserless strategy)</li>
            <li>Anti-bot protection</li>
            <li>Complex page structure</li>
            <li>Site blocking automated requests</li>
          </ul>
          <p>Try switching to a different strategy or check if the site is accessible.</p>
        </div>
      `;
    } else {
      // Show content preview
      const previewItems = Array.from(items)
        .slice(0, 5)
        .map((item) => {
          const title = item.querySelector('title')?.textContent || 'No title';
          const description = item.querySelector('description')?.textContent || 'No description';
          const link = item.querySelector('link')?.textContent || '#';

          return `
          <div class="preview-item">
            <h5><a href="${link}" target="_blank">${title}</a></h5>
            <p>${description.substring(0, 150)}${description.length > 150 ? '...' : ''}</p>
          </div>
        `;
        })
        .join('');

      xmlPreview.innerHTML = `
        <div class="content-preview">
          <h4>📰 Content Preview (${items.length} items found)</h4>
          <div class="preview-items">${previewItems}</div>
          ${items.length > 5 ? `<p class="preview-more">... and ${items.length - 5} more items</p>` : ''}
        </div>
      `;
    }

    xmlPreview.classList.remove('hidden');
  } catch (error) {
    const xmlPreview = document.getElementById('xml-preview');
    if (xmlPreview) {
      xmlPreview.innerHTML = `<div class="content-preview-error">Error loading content preview: ${error.message}</div>`;
      xmlPreview.classList.remove('hidden');
    }
  }
}
