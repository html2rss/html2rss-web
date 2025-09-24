import { useState, useEffect } from 'preact/hooks';

interface ConversionResult {
  id: string;
  name: string;
  url: string;
  username: string;
  strategy: string;
  public_url: string;
}

interface ResultDisplayProps {
  result: ConversionResult;
  onClose: () => void;
}

export function ResultDisplay({ result, onClose }: ResultDisplayProps) {
  const [showRawXml, setShowRawXml] = useState(false);
  const [xmlContent, setXmlContent] = useState<string>('');
  const [isLoadingXml, setIsLoadingXml] = useState(false);

  // Convert relative URL to absolute URL
  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;
  const feedProtocolUrl = `feed:${fullUrl}`;

  // Load raw XML
  useEffect(() => {
    if (showRawXml && !xmlContent) {
      loadRawXml();
    }
  }, [showRawXml]);

  const loadRawXml = async () => {
    setIsLoadingXml(true);
    try {
      const response = await fetch(fullUrl);
      const content = await response.text();
      setXmlContent(content);
    } catch (error) {
      setXmlContent(`Error loading XML: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setIsLoadingXml(false);
    }
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch (error) {
      console.error('Failed to copy:', error);
    }
  };

  // Scroll to result
  useEffect(() => {
    const resultElement = document.getElementById('result-display');
    if (resultElement) {
      resultElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, []);

  return (
    <div id="result-display" class="result-section">
      <div class="success-animation">
        <div class="success-icon">🎉</div>
        <h3>Feed Generated Successfully!</h3>
        <p class="success-subtitle">Your RSS feed is ready to use</p>
      </div>

      <div class="feed-result">
        <div class="feed-url-section">
          <label>
            <strong>📡 Feed URL:</strong>
          </label>
          <div class="feed-url-display">
            <input type="text" value={fullUrl} readonly />
            <button type="button" class="copy-btn" onClick={() => copyToClipboard(fullUrl)}>
              Copy
            </button>
          </div>
        </div>

        <div class="feed-actions">
          <a href={feedProtocolUrl} class="subscribe-button" target="_blank" rel="noopener">
            <span class="button-icon">📰</span>
            <span>Subscribe in RSS Reader</span>
          </a>
          <button type="button" class="copy-feed-button" onClick={() => copyToClipboard(feedProtocolUrl)}>
            <span class="button-icon">📋</span>
            <span>Copy Feed Link</span>
          </button>
        </div>

        <div class="feed-info">
          <p class="feed-instructions">
            <strong>How to use:</strong> Click "Subscribe" to open in your RSS reader, or copy the URL to add
            to any RSS reader manually.
          </p>
          <div class="rss-readers">
            <span class="readers-label">Works with:</span>
            <span class="reader-tag">Feedly</span>
            <span class="reader-tag">Inoreader</span>
            <span class="reader-tag">Thunderbird</span>
            <span class="reader-tag">Apple News</span>
          </div>
        </div>
      </div>

      {/* XML Preview Section */}
      <div class="xml-preview-section">
        <div class="xml-preview-header">
          <h4>📄 RSS Feed Preview</h4>
          <div class="xml-preview-controls">
            <a href={fullUrl} target="_blank" rel="noopener" class="open-feed-btn">
              🔗 Open in New Tab
            </a>
            <button type="button" class="xml-toggle-btn" onClick={() => setShowRawXml(!showRawXml)}>
              {showRawXml ? 'Show Styled Preview' : 'Show Raw XML'}
            </button>
          </div>
        </div>

        {!showRawXml ? (
          <div class="xml-iframe-container">
            <iframe src={fullUrl} class="rss-iframe" title="RSS Feed Preview" />
          </div>
        ) : (
          <div class="xml-raw-container">
            {isLoadingXml ? (
              <div class="loading">Loading raw XML...</div>
            ) : (
              <pre class="xml-content">
                <code>{xmlContent}</code>
              </pre>
            )}
          </div>
        )}
      </div>

      <button onClick={onClose} class="close-result-btn">
        Close
      </button>
    </div>
  );
}
