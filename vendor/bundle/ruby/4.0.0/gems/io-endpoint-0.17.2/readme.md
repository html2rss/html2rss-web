# IO::Endpoint

Provides a separation of concerns interface for IO endpoints. This allows you to write code which is agnostic to the underlying IO implementation.

[![Development Status](https://github.com/socketry/io-endpoint/workflows/Test/badge.svg)](https://github.com/socketry/io-endpoint/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/io-endpoint) for more details.

  - [Getting Started](https://socketry.github.io/io-endpointguides/getting-started/index) - This guide explains how to get started with `io-endpoint`, a library that provides a separation of concerns interface for network I/O endpoints.

  - [Named Endpoints](https://socketry.github.io/io-endpointguides/named-endpoints/index) - This guide explains how to use `IO::Endpoint::NamedEndpoints` to manage multiple endpoints by name, enabling scenarios like running the same application on different protocols or ports.

## Releases

Please see the [project releases](https://socketry.github.io/io-endpointreleases/index) for all releases.

### v0.17.2

  - When the unix path is bigger than what can fit into `struct sockaddr_un`, a shorter temporary path will be used instead and a symlink created at the original path.

### v0.17.1

  - Add `#to_s` and `#inspect` for `IO::Endpoint::NamedEndpoints`.

### v0.17.0

  - Added `IO::Endpoint::NamedEndpoints` for accessing endpoints by symbolic names, useful for running applications on multiple endpoints with different configurations.

### v0.16.0

  - Improved error handling in `#connect` for more robust connection handling.
  - Added getting started guide and improved documentation coverage.

### v0.15.2

  - Fixed `UNIXEndpoint#bind` to pass all arguments through to super.

### v0.15.1

  - Added `async-dns` to externals and restored removed method.

### v0.15.0

  - Allow wrapper to be customized using endpoint `options[:wrapper]`.
  - Expose wrapper extension points for `connect` and `accept`.

### v0.14.0

  - Uniform `#to_s` and `#inspect` implementations across all endpoints.

### v0.13.1

  - Fixed state leak between iterations of the accept loop.

### v0.13.0

  - Propagate options assigned to composite endpoint to nested endpoints.

## See Also

  - [async-io](https://github.com/socketry/async-io) — Where this implementation originally came from.

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
