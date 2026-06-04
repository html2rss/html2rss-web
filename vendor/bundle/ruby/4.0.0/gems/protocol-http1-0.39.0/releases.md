# Releases

## v0.39.0

  - Rename `RequestRefusedError` -\> `RefusedError`.

## v0.38.0

  - `write_request` now raises `Protocol::HTTP::RequestRefusedError` if the request line or headers cannot be written, indicating the request was not processed and can be safely retried.

## v0.37.1

  - Defer `body.close` in `write_chunked_body`, `write_fixed_length_body`, and `write_body_and_close` until after the response is fully written and flushed. Previously, `body.each` called `close` in its `ensure` block before the terminal chunk (chunked encoding) or final flush was written, causing `rack.response_finished` callbacks to delay the client-visible response completion.

## v0.37.0

  - `Protocol::HTTP1::BadRequest` now includes `Protocol::HTTP::BadRequest` for better interoperability and handling of bad request errors across different HTTP protocol implementations.

## v0.36.0

  - Indicate trailers from chunked body for better validation by `Protocol::HTTP::Headers`.

## v0.35.2

  - Tidy up implementation of `read_line?` to handle line length errors and protocol violations more clearly.
  - Improve error handling for unexpected connection closures (`Errno::ECONNRESET`) in `read_line?`.

## v0.35.0

  - Add traces provider for `Protocol::HTTP1::Connection`.

## v0.34.1

  - Fix connection state handling to allow idempotent response body closing.
  - Add `kisaten` fuzzing integration for improved security testing.

## v0.34.0

  - Support empty header values in HTTP parsing for better compatibility.

## v0.33.0

  - Support high-byte characters in HTTP headers for improved international compatibility.

## v0.32.0

  - Fix header parsing to handle tab characters between values correctly.
  - Complete documentation coverage for all public APIs.

## v0.31.0

  - Enforce one-way transition for persistent connections to prevent invalid state changes.

## v0.30.0

  - Make `authority` header optional in HTTP requests for improved flexibility.

## v0.29.0

  - Add block/yield interface to `read_request` and `read_response` methods.

## v0.28.1

  - Fix handling of `nil` lines in HTTP parsing.

## v0.28.0

  - Add configurable maximum line length to prevent denial of service attacks.

## v0.27.0

  - Improve error message clarity and debugging information.
  - Separate state machine logic from connection callbacks for better architecture.

## v0.26.0

  - Improve error handling propagation through connection closure.

## v0.25.0

  - Fix connection stream handling when closing response bodies.
  - Improve connection state management for better reliability.

## v0.24.0

  - Add connection state tracking for safer connection reuse.

## v0.23.0

  - Add `Body#discard` method support for improved resource management.

## v0.22.0

  - Improve handling of underlying stream objects for better stability.

## v0.21.0

  - Fix connection persistence handling for `1xx` responses and remainder bodies.
  - Improve debug output readability by using `.inspect` instead of `.dump`.
  - Enhanced request upgrade body handling.

## v0.20.0

  - Restructure error hierarchy for better error handling consistency.

## v0.19.1

  - Fix stream flushing in `write_body_and_close` for proper connection cleanup.

## v0.19.0

  - Add `#hijacked?` method to check connection hijack status.

## v0.18.0

  - Add persistent connection handling examples.
  - Improve performance by avoiding blocking operations on `eof?` checks.

## v0.17.0

  - Add `HTTP/1` client and server example implementations.

## v0.16.1

  - Allow external control of persistent connection settings.
  - Separate request line and response status line parsing for better maintainability.

## v0.16.0

  - Add support for HTTP interim (informational) responses like `103 Early Hints`.
  - Improve error messages by including `content_length` in debugging output.

## v0.15.1

  - Add strict validation for `content-length` and chunk length values.

## v0.15.0

  - Migrate test suite to `Sus` testing framework with 100% coverage.

## v0.14.6

  - Handle `IOError` for closed streams gracefully.
  - Improve memory management by removing string ownership model.
  - Add early hints server example.

## v0.14.4

  - Improve trailer handling when content length is known in advance.

## v0.14.3

  - Enhanced trailer support with comprehensive test coverage.

## v0.14.2

  - Prefer chunked transfer encoding when possible for better streaming performance.

## v0.14.1

  - Improve error handling when reading chunk length lines.

## v0.14.0

  - Rename "trailers" to "trailer" for HTTP specification compliance.

## v0.13.2

  - Enable `HTTP/1.1` connections to write fixed-length message bodies.

## v0.13.1

  - Fix `HTTP/1` request parsing example in documentation.

## v0.13.0

  - Implement pessimistic flushing strategy for better performance.
  - Add fuzzing infrastructure for security testing.

## v0.12.0

  - Update dependencies to latest compatible versions.

## v0.11.1

  - Improve header and trailer processing logic.
  - Update behavior to match new `write_body` semantics.

## v0.11.0

  - Add comprehensive HTTP trailer support for chunked transfers.
  - Simplify chunked encoding implementation.

## v0.10.3

  - Improve handling of `HEAD` requests and responses.
  - Better error handling for incomplete fixed-length message bodies.

## v0.10.2

  - Add RFC-compliant header validation during read and write operations.
  - Improve performance with `frozen_string_literals: true`.

## v0.10.1

  - Drop support for Ruby 2.3 (end of life).
  - Validate that response header values don't contain `CR` or `LF` characters.

## v0.10.0

  - Parse HTTP `connection` header values as case-insensitive per RFC specification.

## v0.9.0

  - Enhanced `Remainder` body implementation with comprehensive test coverage.
  - Improve HTTP `CONNECT` method handling for both client and server.
  - Improve performance by removing array allocation in method arguments.

## v0.8.3

  - Restore Ruby 2.3 compatibility using monkey patches.
  - Enhanced test suite with improved memory and file handling utilities.

## v0.8.2

  - Simplify HTTP request line validation logic.

## v0.8.1

  - Improve error handling and recovery for malformed HTTP requests.

## v0.8.0

  - Add automatic HTTP reason phrase generation based on status codes.

## v0.7.0

  - Enhanced connection hijacking support for pooled connections.

## v0.6.0

  - Adopt `Protocol::HTTP` Body abstractions for better consistency.
  - Require callers to handle hijacking for `HTTP/1` protocol upgrades.
  - Add flexible request/response body and upgrade handling.
  - Fix WebSocket compatibility issues with Safari browser.

## v0.5.0

  - Return `nil` when unable to read HTTP request line (connection closed).

## v0.4.1

  - Ensure output streams are properly closed within accept blocks.

## v0.4.0

  - Improve handling of HTTP upgrade request and response message bodies.

## v0.3.0

  - Enhanced support for partial connection hijacking and protocol upgrades.

## v0.2.0

  - Improve error handling throughout the codebase.

## v0.1.0

  - Initial public release of `Protocol::HTTP1`.
  - Low-level `HTTP/1.0` and `HTTP/1.1` protocol implementation.
  - Support for persistent connections, chunked transfer encoding, and connection upgrades.
