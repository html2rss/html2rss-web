# Protocol::Rack

Provides abstractions for working with the Rack specification on top of [`Protocol::HTTP`](https://github.com/socketry/protocol-http). This would, in theory, allow you to run any `Protocol::HTTP` compatible application on top any rack-compatible server.

[![Development Status](https://github.com/socketry/protocol-rack/workflows/Test/badge.svg)](https://github.com/socketry/protocol-rack/actions?workflow=Test)

## Features

  - Supports Rack v2 and Rack v3 application adapters.
  - Supports Rack environment to `Protocol::HTTP::Request` adapter.

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-rack/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-rack/guides/getting-started/index) - This guide explains how to get started with `protocol-rack` and integrate Rack applications with `Protocol::HTTP` servers.

  - [Request and Response Handling](https://socketry.github.io/protocol-rack/guides/request-response/index) - This guide explains how to work with requests and responses when bridging between Rack and `Protocol::HTTP`, covering advanced use cases and edge cases.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-rack/releases/index) for all releases.

### v0.22.1

  - Rack 2 should not use `to_ary`.

### v0.22.0

  - Prefer `Protocol::HTTP::Body::Buffered` where possible for enumerable bodies, mainly to avoid creating `Enumerable`s.

### v0.21.1

  - Fix missing `body#close` for streaming bodies.

### v0.21.0

  - For the purpose of constructing the rack request environment, trailers are ignored.

### v0.20.0

  - Convert header values into strings using `to_s` so that `Headers#each` can yield non-string values if necessary.

### v0.19.0

  - Use `Headers#add` instead of `Headers#[]=` in Rack3 and Rack31 adapters, which is the correct interface for appending headers.

### v0.18.0

  - Correctly invoke `rack.response_finished` in reverse order.
  - Tolerate errors during `rack.response_finished` callbacks.

### v0.17.0

  - Support `rack.response_finished` in Rack 2 if it's present in the environment.

### v0.16.0

  - Hijacked IO is no longer duped, as it's not retained by the original connection, and `SSLSocket` does not support duping.

### v0.15.0

  - Use `IO::Stream::Readable` for the input body, which is a better tested and more robust interface.

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

## See Also

  - [protocol-http](https://github.com/socketry/protocol-http) — General abstractions for HTTP client/server implementations.
  - [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client and server, supporting multiple HTTP protocols & TLS, which can host the Rack application adapters (and is used by this gem for testing).
