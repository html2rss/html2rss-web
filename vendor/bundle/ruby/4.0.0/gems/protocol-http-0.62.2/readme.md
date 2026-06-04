# Protocol::HTTP

Provides abstractions for working with the HTTP protocol.

[![Development Status](https://github.com/socketry/protocol-http/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http/actions?workflow=Test)

## Features

  - General abstractions for HTTP requests and responses.
  - Symmetrical interfaces for client and server.
  - Light-weight middleware model for building applications.

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-http/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-http/guides/getting-started/index) - This guide explains how to use `protocol-http` for building abstract HTTP interfaces.

  - [Message Body](https://socketry.github.io/protocol-http/guides/message-body/index) - This guide explains how to work with HTTP request and response message bodies using `Protocol::HTTP::Body` classes.

  - [Headers](https://socketry.github.io/protocol-http/guides/headers/index) - This guide explains how to work with HTTP headers using `protocol-http`.

  - [Middleware](https://socketry.github.io/protocol-http/guides/middleware/index) - This guide explains how to build and use HTTP middleware with `Protocol::HTTP::Middleware`.

  - [Streaming](https://socketry.github.io/protocol-http/guides/streaming/index) - This guide gives an overview of how to implement streaming requests and responses.

  - [Design Overview](https://socketry.github.io/protocol-http/guides/design-overview/index) - This guide explains the high level design of `protocol-http` in the context of wider design patterns that can be used to implement HTTP clients and servers.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-http/releases/index) for all releases.

### v0.62.1

  - Fix handling of `Stream#read(0)`, it must return a mutable string (or clear the given buffer).

### v0.61.0

  - Introduce `Protocol::HTTP::RefusedError` for indicating a stream or request was refused before processing and can be safely retried. `RequestRefusedError` is provided as an alias for backwards compatibility.

### v0.60.0

  - Expose `Protocol::HTTP::Body::Writable#count` attribute to provide access to the number of chunks written to the body.

### v0.59.0

  - Introduce `Protocol::HTTP::Middleware.load` method for loading middleware applications from files.
  - Prevent `ZLib::BufError` when deflating empty chunks by skipping deflation for empty chunks.

### v0.58.1

  - `Protocol::HTTP::DuplicateHeaderError` now includes the existing and new values for better debugging.

### v0.58.0

  - Move trailer validation to `Headers#add` method to ensure all additions are checked at the time of addition as this is a hard requirement.
  - Introduce `Headers#header` method to enumerate only the main headers, excluding trailers. This can be used after invoking `Headers#trailer!` to avoid race conditions.
  - Fix `Headers#to_h` so that indexed headers are not left in an inconsistent state if errors occur during processing.

### v0.57.0

  - Always use `#parse` when parsing header values from strings to ensure proper normalization and validation.
  - Introduce `Protocol::HTTP::InvalidTrailerError` which is raised when a trailer header is not allowed by the current policy.
  - **Breaking**: `Headers#each` now yields parsed values according to the current policy. For the previous behaviour, use `Headers#fields`.

### v0.56.0

  - Introduce `Header::*.parse(value)` which parses a raw header value string into a header instance.
  - Introduce `Header::*.coerce(value)` which coerces any value (`String`, `Array`, etc.) into a header instance with normalization.
  - `Header::*#initialize` now accepts arrays without normalization for efficiency, or strings for backward compatibility.
  - Update `Headers#[]=` to use `coerce(value)` for smart conversion of user input.
  - Normalization (e.g., lowercasing) is applied by `parse`, `coerce`, and `<<` methods, but not by `new` when given arrays.

### v0.55.0

  - **Breaking**: Move `Protocol::HTTP::Header::QuotedString` to `Protocol::HTTP::QuotedString` for better reusability.
  - **Breaking**: Handle cookie key/value pairs using `QuotedString` as per RFC 6265.
      - Don't use URL encoding for cookie key/value.
  - **Breaking**: Remove `Protocol::HTTP::URL` and `Protocol::HTTP::Reference` – replaced by `Protocol::URL` gem.
      - `Protocol::HTTP::URL` -\> `Protocol::URL::Encoding`.
      - `Protocol::HTTP::Reference` -\> `Protocol::URL::Reference`.

### v0.54.0

  - Introduce rich support for `Header::Digest`, `Header::ServerTiming`, `Header::TE`, `Header::Trailer` and `Header::TransferEncoding`.
  - [Improved HTTP Trailer Security](https://socketry.github.io/protocol-http/releases/index#improved-http-trailer-security)

## See Also

  - [protocol-http1](https://github.com/socketry/protocol-http1) — HTTP/1 client/server implementation using this
    interface.
  - [protocol-http2](https://github.com/socketry/protocol-http2) — HTTP/2 client/server implementation using this
    interface.
  - [protocol-url](https://github.com/socketry/protocol-url) — URL parsing and manipulation library.
  - [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client and server, supporting multiple HTTP
    protocols & TLS.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server WebSockets.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
