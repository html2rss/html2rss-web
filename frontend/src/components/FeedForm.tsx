import { useState } from 'preact/hooks';

interface FeedFormProps {
  onConvert: (url: string, name: string, strategy: string) => void;
  isConverting: boolean;
}

export function FeedForm({ onConvert, isConverting }: FeedFormProps) {
  const [url, setUrl] = useState('');
  const [name, setName] = useState('');
  const [strategy, setStrategy] = useState('ssrf_filter');
  const [showAdvanced, setShowAdvanced] = useState(false);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    if (!url) return;

    const feedName = name || `Auto Generated Feed for ${url}`;
    await onConvert(url, feedName, strategy);
  };

  const handleUrlChange = (e: Event) => {
    const target = e.target as HTMLInputElement;
    setUrl(target.value);

    // Auto-generate name from URL if not set
    if (!name && target.value) {
      try {
        const urlObj = new URL(target.value);
        setName(`Feed for ${urlObj.hostname}`);
      } catch {
        // Invalid URL, keep current name
      }
    }
  };

  return (
    <form onSubmit={handleSubmit} class="feed-form">
      <div class="form-group">
        <label for="url">Website URL:</label>
        <input
          type="url"
          id="url"
          name="url"
          value={url}
          onInput={handleUrlChange}
          placeholder="https://example.com"
          required
          disabled={isConverting}
        />
      </div>

      <div class="form-group">
        <label for="name">Feed Name (optional):</label>
        <input
          type="text"
          id="name"
          name="name"
          value={name}
          onInput={(e) => setName((e.target as HTMLInputElement).value)}
          placeholder="Auto-generated from URL"
          disabled={isConverting}
        />
      </div>

      <div class="advanced-section">
        <button type="button" class="advanced-toggle" onClick={() => setShowAdvanced(!showAdvanced)}>
          {showAdvanced ? 'Hide' : 'Show'} Advanced Options
        </button>

        <div class={`advanced-fields ${showAdvanced ? 'show' : ''}`}>
          <div class="form-group">
            <label>Strategy:</label>
            <div class="radio-group">
              <label>
                <input
                  type="radio"
                  name="strategy"
                  value="ssrf_filter"
                  checked={strategy === 'ssrf_filter'}
                  onChange={(e) => setStrategy((e.target as HTMLInputElement).value)}
                  disabled={isConverting}
                />
                SSRF Filter (recommended)
              </label>
              <label>
                <input
                  type="radio"
                  name="strategy"
                  value="browserless"
                  checked={strategy === 'browserless'}
                  onChange={(e) => setStrategy((e.target as HTMLInputElement).value)}
                  disabled={isConverting}
                />
                Browserless (for JS-heavy sites)
              </label>
            </div>
          </div>
        </div>
      </div>

      <button type="submit" disabled={isConverting || !url} class="convert-btn">
        {isConverting ? 'Converting...' : 'Convert to RSS'}
      </button>
    </form>
  );
}
