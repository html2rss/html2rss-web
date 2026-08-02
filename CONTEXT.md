# Domain Context: html2rss-web

This documents the ubiquitous language and domain concepts of the `html2rss-web` service.

## Glossary

### Session
The user's active session context containing the Access Token (for authentication/privileges) and the API Metadata (defining instance config, features, and featured feeds).

### Access Token
A persistent secret token used to authenticate feed creation requests against the instance's security gate.

### Feed Flow
The process of capturing a target page URL, validating it, converting it to an RSS/JSON feed, and monitoring the preview.

### Auto-Submit
A mechanism that automatically initiates feed creation when a prefilled URL is passed to the application route (e.g. from the bookmarklet).

### Renderer
A backend component responsible for format negotiation (RSS or JSON Feed) and serializing the final feed payload or error representation.
