import { useState, useEffect } from 'preact/hooks';
import styles from './ResultDisplay.module.css';

interface ConversionResult {
  id: string;
  name: string;
  url: string;
  username: string;
  strategy: string;
  public_url: string;
}

type PreviewMode = 'preview' | 'xml';

interface ResultDisplayProps {
  result: ConversionResult;
  onClose: () => void;
  isAuthenticated?: boolean;
  username?: string;
  onLogout?: () => void;
}

export function ResultDisplay({ result, onClose, isAuthenticated, username, onLogout }: ResultDisplayProps) {
  const [previewMode, setPreviewMode] = useState<PreviewMode>('preview');
  const [xmlContent, setXmlContent] = useState<string>('');
  const [isLoadingXml, setIsLoadingXml] = useState(false);
  const [xmlError, setXmlError] = useState('');
  const [copyNotice, setCopyNotice] = useState('');
  const previewTabId = 'result-preview-tab-preview';
  const xmlTabId = 'result-preview-tab-xml';
  const panelId = 'result-preview-panel';

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;
  const feedProtocolUrl = `feed:${fullUrl}`;

  useEffect(() => {
    const resultElement = document.getElementById('result-display');
    if (resultElement) {
      resultElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, []);

  useEffect(() => {
    if (previewMode === 'xml' && !xmlContent) {
      loadRawXml();
    }
  }, [previewMode]);

  const loadRawXml = async () => {
    setIsLoadingXml(true);
    setXmlError('');
    try {
      const response = await fetch(fullUrl);
      const content = await response.text();
      setXmlContent(content);
    } catch (error) {
      setXmlError(error instanceof Error ? error.message : 'Unable to load XML preview.');
      setXmlContent('');
    } finally {
      setIsLoadingXml(false);
    }
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopyNotice('Copied to clipboard.');
      window.setTimeout(() => setCopyNotice(''), 3000);
    } catch (error) {
      setCopyNotice('Clipboard copy failed. Please copy the URL manually.');
    }
  };

  return (
    <section id="result-display" class={`surface ${styles.result}`} aria-live="polite">
      <header class={styles.hero}>
        <div class={styles.heroHeadline}>
          <span class={styles.heroIcon} aria-hidden="true">
            🎉
          </span>
          <span class={styles.heroText}>
            <p class={styles.heroEyebrow}>Feed ready</p>
            <h2 class={styles.heroTitle}>Your RSS feed is live!</h2>
            <p class={styles.heroSubtitle}>
              Drop it straight into your reader or explore the preview without leaving this page.
            </p>
          </span>
        </div>
        <div class={styles.heroActions}>
          <a href={feedProtocolUrl} class="btn btn--accent" target="_blank" rel="noopener">
            <span aria-hidden="true">📰</span>
            <span>Subscribe in RSS reader</span>
          </a>
          <button type="button" class="btn btn--ghost" onClick={() => copyToClipboard(feedProtocolUrl)}>
            <span aria-hidden="true">📋</span>
            <span>Copy feed link</span>
          </button>
          <a href={fullUrl} target="_blank" rel="noopener" class="btn btn--ghost">
            <span aria-hidden="true">🔗</span>
            <span>Open feed in new tab</span>
          </a>
        </div>
        {copyNotice && (
          <div class="notice" role="status">
            <p>{copyNotice}</p>
          </div>
        )}
      </header>

      {isAuthenticated && (
        <div class={styles.accountBar}>
          <span>
            Signed in as <strong>{username ?? 'your account'}</strong>
          </span>
          {onLogout && (
            <button type="button" class="btn btn--link" onClick={onLogout}>
              Logout
            </button>
          )}
        </div>
      )}

      <div class={styles.feedCard}>
        <span class={styles.feedLabel}>Feed URL</span>
        <div class={styles.feedInputRow}>
          <input type="text" value={fullUrl} readOnly aria-label="Feed URL" class="input" />
          <button type="button" class="btn btn--ghost" onClick={() => copyToClipboard(fullUrl)}>
            Copy URL
          </button>
        </div>
      </div>

      <div class={styles.preview}>
        <div class={styles.previewTabs} role="tablist" aria-label="Feed preview mode">
          <button
            type="button"
            role="tab"
            aria-selected={previewMode === 'preview'}
            id={previewTabId}
            aria-controls={panelId}
            class={`${styles.tab} ${previewMode === 'preview' ? styles.tabActive : ''}`}
            onClick={() => setPreviewMode('preview')}
          >
            Reader preview
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={previewMode === 'xml'}
            id={xmlTabId}
            aria-controls={panelId}
            class={`${styles.tab} ${previewMode === 'xml' ? styles.tabActive : ''}`}
            onClick={() => setPreviewMode('xml')}
          >
            Raw XML
          </button>
        </div>

        <div
          class={styles.previewSurface}
          role="tabpanel"
          id={panelId}
          aria-labelledby={previewMode === 'preview' ? previewTabId : xmlTabId}
        >
          {previewMode === 'preview' ? (
            <iframe src={fullUrl} class={styles.previewFrame} title="RSS feed preview" />
          ) : (
            <div class={styles.previewXml}>
              {isLoadingXml ? (
                <div class={styles.previewLoading}>Loading raw XML...</div>
              ) : xmlError ? (
                <div class="notice notice--error" role="alert">
                  <p>Failed to load XML preview: {xmlError}</p>
                </div>
              ) : (
                <pre>
                  <code>{xmlContent}</code>
                </pre>
              )}
            </div>
          )}
        </div>
      </div>

      <div class={styles.footer}>
        <button type="button" class="btn btn--accent" onClick={onClose}>
          Convert another website
        </button>
      </div>
    </section>
  );
}
