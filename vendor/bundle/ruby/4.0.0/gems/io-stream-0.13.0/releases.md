# Releases

## v0.13.0

  - `IO::Stream::Duplex(io)` is equivalent to `IO::Stream(io)`.

## v0.12.0

  - Introduce `IO::Stream::Duplex` as a low-level duplex transport for composing separate input and output endpoints.
  - Add `IO::Stream::Duplex(input, output)` as a convenient constructor that returns a buffered stream wrapping a duplex transport.
  - Add a timeout compatibility shim for `StringIO` so duplex streams composed from in-memory endpoints can participate in the timeout interface consistently.
  - Remove old OpenSSL method shims.

## v0.11.0

  - Introduce `class IO::Stream::ConnectionResetError < Errno::ECONNRESET` to standardize connection reset error handling across different IO types.
      - `OpenSSL::SSL::SSLSocket` raises `OpenSSL::SSL::SSLError` on connection reset, while other IO types raise `Errno::ECONNRESET`. `SSLError` is now rescued and re-raised as `IO::Stream::ConnectionResetError` for consistency.

## v0.10.0

  - Rename `done?` to `finished?` for clarity and consistency.

## v0.9.1

  - Fix EOF behavior to match Ruby IO semantics: `read()` returns empty string `""` at EOF while `read(size)` returns `nil` at EOF.

## v0.9.0

  - Add support for `buffer` parameter in `read`, `read_exactly`, and `read_partial` methods to allow reading into a provided buffer.

## v0.8.0

  - On Ruby v3.3+, use `IO#write` directly instead of `IO#write_nonblock`, for better performance.
  - Introduce support for `Readable#discard_until` method to discard data until a specific pattern is found.

## v0.7.0

  - Split stream functionality into separate `Readable` and `Writable` modules for better modularity and composition.
  - Remove unused timeout shim functionality.
  - 100% documentation coverage.

## v0.6.1

  - Fix compatibility with Ruby v3.3.0 - v3.3.6 where broken `@io.close` could hang.

## v0.6.0

  - Improve compatibility of `gets` implementation to better match Ruby's IO\#gets behavior.

## v0.5.0

  - Add support for `read_until(limit:)` parameter to limit the amount of data read.
  - Minor documentation improvements.

## v0.4.3

  - Add comprehensive tests for `buffered?` method on `SSLSocket`.
  - Ensure TLS connections have correct buffering behavior.
  - Improve test suite organization and readability.

## v0.4.2

  - Add external test suite for better integration testing.
  - Update dependencies and improve code style with RuboCop.

## v0.4.1

  - Add compatibility fix for `SSLSocket` raising `EBADF` errors.
  - Fix `IO#close` hang issue in certain scenarios.
  - Add `#to_io` method to `IO::Stream::Buffered` for better compatibility.
  - Modernize gem structure and dependencies.

## v0.4.0

  - Add convenient `IO.Stream()` constructor method for creating buffered streams.

## v0.3.0

  - Add support for timeouts with compatibility shims for various IO types.

## v0.2.0

  - Prefer `write_nonblock` in `syswrite` implementation for better non-blocking behavior.
  - Add test cases for crash scenarios.

## v0.1.1

  - Improve buffering compatibility by falling back to `sync=` when `buffered=` is not available.

## v0.1.0

  - Rename `IO::Stream::BufferedStream` to `IO::Stream::Buffered` for consistency.
  - Add comprehensive tests and improved OpenSSL support with compatibility shims.
  - Improve compatibility with Darwin/macOS systems.
  - Fix monkey patches for various IO types.
  - Add support for `StringIO#buffered?` method.

## v0.0.1

  - Initial release with basic buffered stream functionality.
  - Provide `IO::Stream::Buffered` class for efficient buffered I/O operations.
  - Add `readable?` method to check stream readability status.
  - Include basic test suite.
