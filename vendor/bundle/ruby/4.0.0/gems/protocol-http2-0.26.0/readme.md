# Protocol::HTTP2

Provides a low-level implementation of the HTTP/2 protocol.

[![Development Status](https://github.com/socketry/protocol-http2/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http2/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-http2/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-http2/guides/getting-started/index) - This guide explains how to use the `protocol-http2` gem to implement a basic HTTP/2 client.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-http2/releases/index) for all releases.

### v0.26.0

  - On RST\_STREAM with REFUSED\_STREAM, close the stream with `Protocol::HTTP::RefusedError` instead of `StreamError`.

### v0.25.0

  - On GOAWAY, proactively close unprocessed streams (ID above `last_stream_id`) with `Protocol::HTTP::RequestRefusedError`, enabling safe retry of non-idempotent requests.

### v0.24.0

  - When closing a connection with active streams, if an error is not provided, it will default to `EOFError` so that streams propagate the closure correctly.

### v0.23.0

  - Introduce a limit to the number of CONTINUATION frames that can be read to prevent resource exhaustion. The default limit is 8 continuation frames, which means a total of 9 frames (1 initial + 8 continuation). This limit can be adjusted by passing a different value to the `limit` parameter in the `Continued.read` method. Setting the limit to 0 will only read the initial frame without any continuation frames. In order to change the default, you can redefine the `LIMIT` constant in the `Protocol::HTTP2::Continued` module, OR you can pass a different frame class to the framer.

### v0.22.1

  - Improved tracing performance by only tracing framer operations when in an active trace context.
  - Updated `protocol-http` dependency version in gemspec.
  - Code modernization and documentation improvements.

### v0.22.0

  - [Added Priority Update Frame and Stream Priority](https://socketry.github.io/protocol-http2/releases/index#added-priority-update-frame-and-stream-priority)

### v0.21.0

  - **Breaking**: Removed support for priority frame and stream dependencies. The `Protocol::HTTP2::Stream` class no longer tracks dependencies, and `Stream#send_headers` no longer takes `priority` as the first argument. This change simplifies the internal implementation significantly as HTTP/2 priority frames have been deprecated in the protocol specification.

### v0.20.0

  - Improved performance of dependency management by avoiding linear search operations.
  - Removed `traces` as a required dependency - it's now optional and only used when explicitly needed.
  - Added better documentation for `maximum_concurrent_streams` setting.
  - Restored 100% test coverage and exposed trace provider for optional tracing support.

### v0.19.4

  - Reduced the number of window update frames sent to improve network efficiency.

### v0.19.3

  - Improved window update frame handling and performance optimizations.
  - Better implementation of `Window#inspect` for debugging.

## See Also

  - [Async::HTTP](https://github.com/socketry/async-http) - A high-level HTTP client and server implementation.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Running Tests

To run the test suite:

``` shell
bundle exec sus
```

### Making Releases

To make a new release:

``` shell
bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
