# Releases

## v0.26.0

  - On RST\_STREAM with REFUSED\_STREAM, close the stream with `Protocol::HTTP::RefusedError` instead of `StreamError`.

## v0.25.0

  - On GOAWAY, proactively close unprocessed streams (ID above `last_stream_id`) with `Protocol::HTTP::RequestRefusedError`, enabling safe retry of non-idempotent requests.

## v0.24.0

  - When closing a connection with active streams, if an error is not provided, it will default to `EOFError` so that streams propagate the closure correctly.

## v0.23.0

  - Introduce a limit to the number of CONTINUATION frames that can be read to prevent resource exhaustion. The default limit is 8 continuation frames, which means a total of 9 frames (1 initial + 8 continuation). This limit can be adjusted by passing a different value to the `limit` parameter in the `Continued.read` method. Setting the limit to 0 will only read the initial frame without any continuation frames. In order to change the default, you can redefine the `LIMIT` constant in the `Protocol::HTTP2::Continued` module, OR you can pass a different frame class to the framer.

## v0.22.1

  - Improved tracing performance by only tracing framer operations when in an active trace context.
  - Updated `protocol-http` dependency version in gemspec.
  - Code modernization and documentation improvements.

## v0.22.0

### Added Priority Update Frame and Stream Priority

HTTP/2 has deprecated the priority frame and stream dependency tracking. This feature has been effectively removed from the protocol. As a consequence, the internal implementation is greatly simplified. The `Protocol::HTTP2::Stream` class no longer tracks dependencies, and this includes `Stream#send_headers` which no longer takes `priority` as the first argument.

Optional per-request priority can be set using the `priority` header instead, and this value can be manipulated using the priority update frame.

## v0.21.0

  - **Breaking**: Removed support for priority frame and stream dependencies. The `Protocol::HTTP2::Stream` class no longer tracks dependencies, and `Stream#send_headers` no longer takes `priority` as the first argument. This change simplifies the internal implementation significantly as HTTP/2 priority frames have been deprecated in the protocol specification.

## v0.20.0

  - Improved performance of dependency management by avoiding linear search operations.
  - Removed `traces` as a required dependency - it's now optional and only used when explicitly needed.
  - Added better documentation for `maximum_concurrent_streams` setting.
  - Restored 100% test coverage and exposed trace provider for optional tracing support.

## v0.19.4

  - Reduced the number of window update frames sent to improve network efficiency.

## v0.19.3

  - Improved window update frame handling and performance optimizations.
  - Better implementation of `Window#inspect` for debugging.

## v0.19.2

  - Added traces to framer for better debugging and monitoring capabilities.
  - Minor fixes to logging output.

## v0.19.1

  - Performance improvements for synchronized output handling.
  - Extracted `window.rb` into separate module for better organization.

## v0.19.0

  - Removed unused `opened` hook that was never utilized.
  - Improved ASCII art diagram in documentation.
  - Modernized gem structure and dependencies.
  - Moved test fixtures into proper namespace organization.

## v0.18.0

  - Fixed `maximum_connection_streams` reference to use `@remote_settings`.
  - Modernized gem structure and dependencies.
  - Improved flush synchronization - `#flush` is already synchronized.

## v0.17.0

  - Exposed synchronize flush functionality for better concurrency control.
  - Improved single line responsibility in code structure.
  - Enhanced error handling - fail in `Connection#write_frames` if `@framer` is `nil`.
  - Fixed broken test cases.

## v0.16.0

  - Removed unused `bake-github-pages` gem dependency.
  - Modernized gem structure and build process.
  - Updated development dependencies and workflows.

## v0.15.0

  - Achieved 100% test coverage with comprehensive test improvements.
  - Fixed multiple minor bugs discovered through enhanced testing.
  - Modernized gem structure and development workflow.
  - Improved maximum concurrent stream handling - now defined only by local settings.
  - Added missing require statements in version tests.

## v0.14.0

  - Added fuzzing support for the framer to improve robustness.
  - Improved connection closed state determination.
  - Enhanced error handling by ignoring expected errors.
  - Optimized AFL (American Fuzzy Lop) latency handling.

## v0.13.0

  - Added methods for handling state transitions.
  - Removed `pry` and `rake` dependencies for cleaner gem structure.
  - Improved debugging and development workflow.

## v0.12.0

  - Updated supported Ruby versions.
  - Significantly improved flow control handling, allowing connection local window to have desired high water mark.
  - Enhanced window management for better performance.

## v0.11.0

  - Separated stream and priority logic to improve memory efficiency.
  - Added Ruby 2.7 support to continuous integration.
  - Improved code organization and performance.

## v0.10.0

  - Improved child stream handling - don't consider child in future stream priority computations.
  - Enhanced state transitions to cache number of currently active streams.
  - Performance optimizations for stream management.

## v0.9.0

  - Split window handling for sub-classes to improve modularity.
  - Fixed Travis CI badge in documentation.
  - Enhanced window management architecture.

## v0.8.0

  - Added support for synchronizing output to prevent headers from being encoded out of order.
  - Improved header handling reliability and consistency.

## v0.7.0

  - Introduced explicit `StreamError` for stream reset codes.
  - Added `HeaderError` for tracking header-specific problems (e.g., invalid pseudo-headers).
  - Removed `send_failure` method as it was not useful.
  - Improved `header_table_size` handling.
  - Enhanced stream priority handling and parent/child relationships.
  - Better flow control and priority management.
  - Improved debugging output and error validation.
  - Enhanced handling of `end_stream` and connection management.
  - Added stream buffer implementation with window update integration.
  - Implemented basic stream priority handling.
  - Improved goaway frame handling.

## v0.6.0

  - Better handling of GOAWAY frames.
  - Improved connection termination procedures.

## v0.5.0

  - Improved handling of stream creation and push promises.
  - Enhanced stream lifecycle management.

## v0.4.0

  - Improved validation of stream ID and error handling.
  - Enhanced flow control implementation.
  - Better RFC compliance with HTTP/2 specification.
  - Fixed priority frame validation - fail if priority depends on own stream.
  - Improved ping frame length checking.
  - Enhanced logging messages and error reporting.

## v0.3.0

  - Added support for `ENABLE_CONNECT_PROTOCOL` setting.
  - Better handling of underlying IO being closed.
  - Improved connection management and error handling.
  - Enhanced coverage reporting.

## v0.2.1

  - Fixed header length and EOF handling.
  - Improved error boundary conditions.

## v0.2.0

  - Significantly improved error handling throughout the library.
  - Better exception management and error reporting.

## v0.1.1

  - Fixed HPACK usage and integration.
  - Corrected header compression/decompression handling.

## v0.1.0

  - Initial migration of HTTP/2 protocol implementation from `http-protocol`.
  - Basic HTTP/2 frame parsing and generation.
  - Integration with `protocol-hpack` for header compression.
  - Stream management and flow control foundation.
  - Connection lifecycle management.
  - Support for all standard HTTP/2 frame types.
  - Basic client and server implementations.
