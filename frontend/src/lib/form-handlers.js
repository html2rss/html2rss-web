// Form handling functions for authentication and feed creation

export function setupFormHandlers() {
  setupAuthForm();
  setupFeedForm();
  handleUrlParams();
}

function setupAuthForm() {
  const authForm = document.getElementById('auth-form');
  if (!authForm) return;

  authForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    const formData = new FormData(authForm);
    const username = formData.get('username');
    const token = formData.get('token');

    if (!username || !token) {
      showError('Please enter both username and token');
      return;
    }

    // Store auth data
    localStorage.setItem('html2rss_username', username);
    localStorage.setItem('html2rss_token', token);

    // Show main content
    showView('main');
    showSuccess(`Welcome, ${username}!`);
  });
}

function setupFeedForm() {
  const autoSourceForm = document.getElementById('auto-source-form');
  if (!autoSourceForm) return;

  autoSourceForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    const formData = new FormData(autoSourceForm);
    const url = formData.get('url');
    const name = formData.get('name') || 'Auto Generated Feed';
    const strategy = formData.get('strategy') || 'ssrf_filter';

    if (!url) {
      showError('Please enter a URL');
      return;
    }

    // Get auth token
    const authToken = localStorage.getItem('html2rss_token');
    if (!authToken) {
      showError('Please authenticate first');
      return;
    }

    const submitBtn = autoSourceForm.querySelector('button[type="submit"]');
    if (submitBtn) {
      submitBtn.textContent = 'Converting...';
      submitBtn.disabled = true;
    }

    try {
      const response = await fetch('/auto_source/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Bearer ${authToken}`,
        },
        body: new URLSearchParams({ url, name, strategy }),
      });

      if (!response.ok) {
        throw new Error(`API call failed: ${response.status}`);
      }

      const feedData = await response.json();
      showFeedResult(feedData.public_url);

      // Show both content preview and raw XML
      await showContentPreview(feedData.public_url);
      await fetchAndDisplayRSS(feedData.public_url);
    } catch (error) {
      showError(`Error generating feed: ${error.message}`);
    } finally {
      if (submitBtn) {
        submitBtn.textContent = 'Convert';
        submitBtn.disabled = false;
      }
    }
  });
}

function handleUrlParams() {
  const params = new URLSearchParams(window.location.search);
  const url = params.get('url');
  const strategy = params.get('strategy');
  if (url) {
    const urlInput = document.getElementById('url');
    if (urlInput) urlInput.value = url;
  }
  if (strategy) {
    setTimeout(() => {
      const strategyRadio = document.querySelector(`input[name="strategy"][value="${strategy}"]`);
      if (strategyRadio) strategyRadio.checked = true;
    }, 100);
  }
}

// View management
export function showView(view) {
  const authSection = document.getElementById('auth-section');
  const mainContent = document.getElementById('main-content');
  const urlInput = document.getElementById('url');
  const advancedFields = document.getElementById('advanced-fields');
  const formLayout = document.querySelector('.form-layout');

  if (view === 'auth') {
    if (authSection) authSection.classList.remove('hidden');
    if (mainContent) mainContent.classList.add('hidden');
    if (urlInput) urlInput.classList.add('hidden');
    if (advancedFields) advancedFields.classList.add('hidden');
    if (formLayout) formLayout.classList.remove('authenticated');
  } else {
    if (authSection) authSection.classList.add('hidden');
    if (mainContent) mainContent.classList.remove('hidden');
    if (urlInput) urlInput.classList.remove('hidden');
    if (formLayout) formLayout.classList.add('authenticated');
    // Don't force show advanced fields - let user toggle them
  }
}

// Utility functions
export function showFeedResult(feedUrl) {
  const resultSection = document.getElementById('result');
  const resultHeading = document.getElementById('result-heading');

  // Convert relative URL to absolute URL
  const fullUrl = feedUrl.startsWith('http') ? feedUrl : `${window.location.origin}${feedUrl}`;
  const feedProtocolUrl = `feed:${fullUrl}`;

  if (resultSection) {
    resultSection.classList.remove('hidden');
    resultSection.innerHTML = `
      <h3 id="result-heading">✅ Feed Generated Successfully!</h3>
      <div class="feed-result">
        <p><strong>Feed URL:</strong></p>
        <div class="feed-url-display">
          <input type="text" value="${fullUrl}" readonly />
          <button type="button" onclick="navigator.clipboard.writeText('${fullUrl}')">Copy</button>
        </div>

        <div class="feed-actions">
          <a href="${feedProtocolUrl}" class="subscribe-button" target="_blank" rel="noopener">
            📰 Subscribe in RSS Reader
          </a>
          <button type="button" onclick="navigator.clipboard.writeText('${feedProtocolUrl}')" class="copy-feed-button">
            📋 Copy Feed Link
          </button>
        </div>

        <p class="feed-instructions">
          Use the subscribe button to open in your default RSS reader, or copy the URL to use in any RSS reader.
        </p>
      </div>
    `;
  }
}

export function showError(message) {
  const resultSection = document.getElementById('result');
  if (resultSection) {
    resultSection.classList.remove('hidden');
    resultSection.innerHTML = `
      <h3 style="color: #d73a49;">❌ Error</h3>
      <p>${message}</p>
    `;
  }
}

export function showSuccess(message) {
  const resultSection = document.getElementById('result');
  if (resultSection) {
    resultSection.classList.remove('hidden');
    resultSection.innerHTML = `
      <h3 style="color: #28a745;">✅ Success</h3>
      <p>${message}</p>
    `;
  }
}
