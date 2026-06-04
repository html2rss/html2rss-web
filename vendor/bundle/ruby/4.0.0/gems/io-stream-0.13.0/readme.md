# IO::Stream

Provide a buffered stream implementation for Ruby, independent of the underlying IO.

[![Development Status](https://github.com/socketry/io-stream/workflows/Test/badge.svg)](https://github.com/socketry/io-stream/actions?workflow=Test)

## Motivation

I built this gem because working with IO in Ruby can be surprisingly difficult. Ruby provides buffering, but the inconsistencies between different IO types made it impossible to write clean, generic code. `OpenSSL::SSL::SSLSocket` maintains its own buffering implementation that behaves differently from regular IO. Some IO types raise `OpenSSL::SSL::SSLError` on connection reset while others raise `Errno::ECONNRESET`. EOF semantics vary. Close operations can hang (especially with SSL sockets). And if you want to work with non-blocking IO using `read_nonblock` and `write_nonblock`, you're constantly handling `:wait_readable` and `:wait_writable` conditions, managing timeouts, and dealing with edge cases that differ across implementations.

By providing a standard interface for buffered IO, `io-stream` allows you to write code that works the same way regardless of the underlying IO type. You can wrap any IO object and get consistent buffering behavior, unified error handling, and proper management of blocking/non-blocking operations. This makes it much easier to write high-performance IO code without worrying about the quirks of each specific IO implementation. Over time, as we've upstreamed more fixes into Ruby, we've been able to reduce the number of workarounds needed, but the core value of `io-stream` remains: a single, predictable interface for all your IO needs.

## Usage

Please see the [project documentation](https://socketry.github.io/io-stream/) for more details.

  - [Getting Started](https://socketry.github.io/io-stream/guides/getting-started/index) - This guide explains how to use `io-stream` to add efficient buffering to Ruby IO objects.

  - [High Performance IO](https://socketry.github.io/io-stream/guides/high-performance-io/index) - This guide explains how to achieve optimal performance when using `io-stream` by understanding and controlling flush behavior.

## Releases

Please see the [project releases](https://socketry.github.io/io-stream/releases/index) for all releases.

### v0.13.0

  - `IO::Stream::Duplex(io)` is equivalent to `IO::Stream(io)`.

### v0.12.0

  - Introduce `IO::Stream::Duplex` as a low-level duplex transport for composing separate input and output endpoints.
  - Add `IO::Stream::Duplex(input, output)` as a convenient constructor that returns a buffered stream wrapping a duplex transport.
  - Add a timeout compatibility shim for `StringIO` so duplex streams composed from in-memory endpoints can participate in the timeout interface consistently.
  - Remove old OpenSSL method shims.

### v0.11.0

  - Introduce `class IO::Stream::ConnectionResetError < Errno::ECONNRESET` to standardize connection reset error handling across different IO types.
      - `OpenSSL::SSL::SSLSocket` raises `OpenSSL::SSL::SSLError` on connection reset, while other IO types raise `Errno::ECONNRESET`. `SSLError` is now rescued and re-raised as `IO::Stream::ConnectionResetError` for consistency.

### v0.10.0

  - Rename `done?` to `finished?` for clarity and consistency.

### v0.9.1

  - Fix EOF behavior to match Ruby IO semantics: `read()` returns empty string `""` at EOF while `read(size)` returns `nil` at EOF.

### v0.9.0

  - Add support for `buffer` parameter in `read`, `read_exactly`, and `read_partial` methods to allow reading into a provided buffer.

### v0.8.0

  - On Ruby v3.3+, use `IO#write` directly instead of `IO#write_nonblock`, for better performance.
  - Introduce support for `Readable#discard_until` method to discard data until a specific pattern is found.

### v0.7.0

  - Split stream functionality into separate `Readable` and `Writable` modules for better modularity and composition.
  - Remove unused timeout shim functionality.
  - 100% documentation coverage.

### v0.6.1

  - Fix compatibility with Ruby v3.3.0 - v3.3.6 where broken `@io.close` could hang.

### v0.6.0

  - Improve compatibility of `gets` implementation to better match Ruby's IO\#gets behavior.

## See Also

  - [async-io](https://github.com/socketry/async-io) — Where this implementation originally came from.

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
