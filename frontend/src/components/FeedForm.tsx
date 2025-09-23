import { useState } from 'preact/hooks';

interface FeedFormProps {
  onConvert: (url: string, strategy: string) => void;
  isConverting: boolean;
}

export function FeedForm({ onConvert, isConverting }: FeedFormProps) {
  const [url, setUrl] = useState('');
  const [strategy, setStrategy] = useState('ssrf_filter');
  const [showAdvanced, setShowAdvanced] = useState(false);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    if (!url) return;

    await onConvert(url, strategy);
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
          onInput={(e) => setUrl((e.target as HTMLInputElement).value)}
          placeholder="https://example.com"
          required
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
