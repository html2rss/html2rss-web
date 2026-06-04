![html2rss logo](https://github.com/html2rss/html2rss/raw/master/support/logo.png)

[![Gem Version](https://badge.fury.io/rb/html2rss.svg)](http://rubygems.org/gems/html2rss) [![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](https://www.rubydoc.info/gems/html2rss) ![Retro Badge: valid RSS](https://validator.w3.org/feed/images/valid-rss-rogers.png) [![CI](https://github.com/html2rss/html2rss/workflows/lint%20and%20test/badge.svg)](https://github.com/html2rss/html2rss/actions)

`html2rss` is a Ruby gem that generates RSS 2.0 feeds from websites by scraping HTML or JSON content with **CSS selectors** or **auto-detection**.

This gem is the core of the [html2rss-web](https://github.com/html2rss/html2rss-web) application.

Most people looking for a first working feed should start with `html2rss-web`, run it with Docker, and open one of the included feeds from their own instance before moving to custom configs or the gem APIs.

## Documentation

Detailed usage guides, reference docs, and the feed directory live on the project website:

- [Ruby gem documentation](https://html2rss.github.io/ruby-gem)
- [Web application](https://html2rss.github.io/web-application)
- [Feed directory](https://html2rss.github.io/feed-directory)
- [Contributing guide](https://html2rss.github.io/get-involved/contributing)
- [GitHub Discussions](https://github.com/orgs/html2rss/discussions)
- [Sponsor on GitHub](https://github.com/sponsors/gildesmarais)

### 💻 Try in Browser

You can develop html2rss directly in your browser using GitHub Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?repo=html2rss/html2rss)

The Codespace comes pre-configured with Ruby 3.4 (compatible with Ruby 4.0), all dependencies, and VS Code extensions ready to go!

## 🤝 Contributing

Please see the [contributing guide](https://html2rss.github.io/get-involved/contributing) for details on how to contribute.

## 🏗️ Architecture

### Core Components

1. **Config** - Loads and validates configuration (YAML/hash)
2. **RequestService** - Fetches pages using Faraday, Botasaurus, or Browserless
3. **Selectors** - Extracts content via CSS selectors with extractors/post-processors
4. **AutoSource** - Auto-detects content using Schema.org, JSON state blobs, semantic HTML, and structural patterns
5. **RssBuilder** - Assembles Article objects and renders RSS 2.0

### Data Flow

```text
Config -> Request -> Extraction -> Processing -> Building -> Output
```

### Request Strategies

- `auto` (default): pipeline fallback orchestration (`faraday` -> `botasaurus` -> `browserless`) based on extraction outcome and retry policy.
- `faraday`: direct HTTP fetch.
- `botasaurus`: delegates fetching to a Botasaurus scrape API. Requires `BOTASAURUS_SCRAPER_URL` (for example `http://localhost:4010`).
- `browserless`: remote browser rendering via Browserless (`BROWSERLESS_IO_WEBSOCKET_URL` and token as needed).

Auto fallback shares one request budget across all strategy attempts. For pagination-heavy or dynamic pages, increase `request.max_requests` (or `--max-requests`) when retries exhaust the budget.

Auto fallback decisions are hidden at the default `LOG_LEVEL=warn`; run with `LOG_LEVEL=info` to include them in CLI output.

Supported `request.botasaurus` options:

- `navigation_mode` (`auto`, `get`, `google_get`, `google_get_bypass`; default `auto`)
- `max_retries` (`0..3`; default `2`)
- `wait_for_selector` (string)
- `wait_timeout_seconds` (integer)
- `block_images` (boolean)
- `block_images_and_css` (boolean)
- `wait_for_complete_page_load` (boolean)
- `headless` (boolean, default `false`)
- `proxy` (string)
- `user_agent` (string)
- `window_size` (two-item integer array, for example `[1920, 1080]`)
- `lang` (string, for example `en-US`)

Minimal YAML config example:

```yaml
channel:
  url: https://example.com
strategy: botasaurus
auto_source: {}
request:
  botasaurus:
    navigation_mode: auto
    max_retries: 2
    headless: false
```

Example request payload shape:

```json
{
  "url": "https://example.com",
  "navigation_mode": "auto",
  "max_retries": 2,
  "headless": false
}
```

Example usage:

```bash
BOTASAURUS_SCRAPER_URL=http://localhost:4010 html2rss auto https://example.com --strategy botasaurus
```

Policy note: html2rss still enforces local request policy preflight and timeout budget. Botasaurus handles browser navigation/rendering internals, so some policy details are delegated to upstream execution.

### Config schema workflow

The config schema is generated from the runtime `dry-validation` contracts and exported for client-side tooling.

- Ruby API: `Html2rss::Config.json_schema`
- CLI: `html2rss schema`
- CLI options:
  - `html2rss schema --write tmp/html2rss-config.schema.json`
  - `html2rss schema --no-pretty`
- Runtime validation API: `Html2rss::Config.validate(config_hash)`
- Runtime validation CLI: `html2rss validate config.yml`
- Packaged JSON file: `schema/html2rss-config.schema.json`

If you are an editor integration, automation script, or AI tool, prefer these stable discovery points:

- call `html2rss schema` to read the current exported schema
- read `schema/html2rss-config.schema.json` when working from the repository or installed gem
- use `Html2rss::Config.schema_path` if you already have Ruby loaded
- use `Html2rss::Config.validate` or `html2rss validate config.yml` when you need authoritative runtime validation of selector references

Run `bundle exec rake config:schema` before committing to regenerate `schema/html2rss-config.schema.json` and keep the checked-in JSON Schema in sync with the validators. The exported schema covers client-side validation, while runtime validation remains authoritative for dynamic cross-field checks such as selector-key references.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💖 Sponsoring

If you find `html2rss` useful, please consider [sponsoring the project](https://github.com/sponsors/gildesmarais).
