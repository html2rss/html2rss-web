// Form handling functions for authentication and feed creation

export function setupFormHandlers() {
  setupAuthForm();
  setupFeedForm();
  setupLogoutButton();
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

    // Update user display
    updateUserDisplay(username);

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

function setupLogoutButton() {
  const logoutButton = document.getElementById('logout-button');
  if (!logoutButton) return;

  logoutButton.addEventListener('click', () => {
    // Clear stored credentials
    localStorage.removeItem('html2rss_username');
    localStorage.removeItem('html2rss_token');

    // Clear any results
    const resultSection = document.getElementById('result');
    if (resultSection) {
      resultSection.classList.add('hidden');
    }

    // Show demo view
    showView('demo');

    // Clear form fields
    const urlInput = document.getElementById('url');
    if (urlInput) urlInput.value = '';

    const nameInput = document.getElementById('name');
    if (nameInput) nameInput.value = '';

    // Show success message
    showSuccess('Logged out successfully');
  });
}

function updateUserDisplay(username) {
  const userDisplay = document.getElementById('user-display');
  if (userDisplay) {
    userDisplay.textContent = username;
  }
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
  const demoSection = document.getElementById('demo-section');
  const authSection = document.getElementById('auth-section');
  const mainContent = document.getElementById('main-content');
  const urlInput = document.getElementById('url');
  const advancedFields = document.getElementById('advanced-fields');
  const formLayout = document.querySelector('.form-layout');

  // Hide main content first
  if (mainContent) mainContent.classList.add('hidden');

  if (view === 'demo') {
    if (demoSection) demoSection.classList.remove('hidden');
    if (authSection) authSection.classList.remove('hidden');
    if (formLayout) formLayout.classList.remove('authenticated');
  } else if (view === 'auth') {
    if (demoSection) demoSection.classList.remove('hidden');
    if (authSection) authSection.classList.remove('hidden');
    if (urlInput) urlInput.classList.add('hidden');
    if (advancedFields) advancedFields.classList.add('hidden');
    if (formLayout) formLayout.classList.remove('authenticated');
  } else if (view === 'main') {
    if (demoSection) demoSection.classList.add('hidden');
    if (mainContent) mainContent.classList.remove('hidden');
    if (authSection) authSection.classList.add('hidden');
    if (urlInput) urlInput.classList.remove('hidden');
    if (formLayout) formLayout.classList.add('authenticated');
    // Don't force show advanced fields - let user toggle them
  }
}

// Utility functions
export function showFeedResult(feedUrl) {
  const resultSection = document.getElementById('result');
  const resultHeading = document.getElementById('result-heading');

  // Validate feedUrl
  if (!feedUrl) {
    showError('No feed URL received from server');
    return;
  }

  // Convert relative URL to absolute URL
  const fullUrl = feedUrl.startsWith('http') ? feedUrl : `${window.location.origin}${feedUrl}`;
  const feedProtocolUrl = `feed:${fullUrl}`;

  if (resultSection) {
    resultSection.classList.remove('hidden');
    resultSection.innerHTML = `
      <div class="success-animation">
        <div class="success-icon">🎉</div>
        <h3 id="result-heading">Feed Generated Successfully!</h3>
        <p class="success-subtitle">Your RSS feed is ready to use</p>
      </div>

      <div class="feed-result">
        <div class="feed-url-section">
          <label><strong>📡 Feed URL:</strong></label>
          <div class="feed-url-display">
            <input type="text" value="${fullUrl}" readonly />
            <button type="button" class="copy-btn" onclick="copyToClipboard('${fullUrl}', this)">
              <span class="copy-text">Copy</span>
              <span class="copy-success hidden">✓</span>
            </button>
          </div>
        </div>

        <div class="feed-actions">
          <a href="${feedProtocolUrl}" class="subscribe-button" target="_blank" rel="noopener">
            <span class="button-icon">📰</span>
            <span>Subscribe in RSS Reader</span>
          </a>
          <button type="button" class="copy-feed-button" onclick="copyToClipboard('${fullUrl}', this)">
            <span class="button-icon">📋</span>
            <span>Copy Feed Link</span>
          </button>
        </div>

        <div class="feed-info">
          <p class="feed-instructions">
            <strong>How to use:</strong> Click "Subscribe" to open in your RSS reader, or copy the URL to add to any RSS reader manually.
          </p>
        </div>
      </div>
    `;

    // Scroll to result section with smooth behavior
    resultSection.scrollIntoView({
      behavior: 'smooth',
      block: 'start',
    });
  }
}

// Copy to clipboard function
window.copyToClipboard = function (text, button) {
  navigator.clipboard
    .writeText(text)
    .then(() => {
      const copyText = button.querySelector('.copy-text');
      const copySuccess = button.querySelector('.copy-success');

      if (copyText && copySuccess) {
        copyText.classList.add('hidden');
        copySuccess.classList.remove('hidden');

        setTimeout(() => {
          copyText.classList.remove('hidden');
          copySuccess.classList.add('hidden');
        }, 2000);
      }
    })
    .catch((err) => {
      console.error('Failed to copy: ', err);
    });
};

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
