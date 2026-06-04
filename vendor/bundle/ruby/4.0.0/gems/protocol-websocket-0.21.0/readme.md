# Protocol::WebSocket

Provides a low-level implementation of the WebSocket protocol according to [RFC6455](https://tools.ietf.org/html/rfc6455). It only implements the latest stable version (13).

[![Development Status](https://github.com/socketry/protocol-websocket/workflows/Test/badge.svg)](https://github.com/socketry/protocol-websocket/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-websocket/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-websocket/guides/getting-started/index) - This guide explains how to use `protocol-websocket` for implementing a websocket client and server.

  - [Extensions](https://socketry.github.io/protocol-websocket/guides/extensions/index) - This guide explains how to use `protocol-websocket` for implementing a websocket client and server using extensions.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-websocket/releases/index) for all releases.

### v0.21.0

  - All frame reading and writing logic has been consolidated into `Framer` to improve performance.

### v0.20.2

  - Fix error messages for `Frame` to be more descriptive.

### v0.20.1

  - Revert masking enforcement option introduced in v0.20.0 due to compatibility issues.

### v0.20.0

  - Introduce option `requires_masking` to `Framer` for enforcing masking on received frames.

### v0.19.1

  - Ensure ping reply payload is packed correctly.

### v0.19.0

  - Default to empty string for message buffer when no data is provided.

### v0.18.0

  - Add `PingMessage` alongside `TextMessage` and `BinaryMessage` for a consistent message interface.
  - Remove `JSONMessage` (use application-level encoding instead).

### v0.17.0

  - Introduce `#close_write` and `#shutdown` methods on `Connection` for more precise connection lifecycle control.

### v0.16.0

  - Move `#send` logic into `Message` for better encapsulation.
  - Improve error handling when a `nil` message is passed.

### v0.15.0

  - Require `Message` class by default.

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
