# Protocol::HTTP1

Provides a low-level implementation of the HTTP/1 protocol.

[![Development Status](https://github.com/socketry/protocol-http1/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http1/actions?workflow=Test)

## Installation

Add this line to your application's Gemfile:

``` ruby
gem "protocol-http1"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install protocol-http1

## Usage

Please see the [project documentation](https://socketry.github.io/protocol-http1/) for more details.

  - [Getting Started](https://socketry.github.io/protocol-http1/guides/getting-started/index) - This guide explains how to get started with `protocol-http1`, a low-level implementation of the HTTP/1 protocol for building HTTP clients and servers.

## Releases

Please see the [project releases](https://socketry.github.io/protocol-http1/releases/index) for all releases.

### v0.39.0

  - Rename `RequestRefusedError` -\> `RefusedError`.

### v0.38.0

  - `write_request` now raises `Protocol::HTTP::RequestRefusedError` if the request line or headers cannot be written, indicating the request was not processed and can be safely retried.

### v0.37.1

  - Defer `body.close` in `write_chunked_body`, `write_fixed_length_body`, and `write_body_and_close` until after the response is fully written and flushed. Previously, `body.each` called `close` in its `ensure` block before the terminal chunk (chunked encoding) or final flush was written, causing `rack.response_finished` callbacks to delay the client-visible response completion.

### v0.37.0

  - `Protocol::HTTP1::BadRequest` now includes `Protocol::HTTP::BadRequest` for better interoperability and handling of bad request errors across different HTTP protocol implementations.

### v0.36.0

  - Indicate trailers from chunked body for better validation by `Protocol::HTTP::Headers`.

### v0.35.2

  - Tidy up implementation of `read_line?` to handle line length errors and protocol violations more clearly.
  - Improve error handling for unexpected connection closures (`Errno::ECONNRESET`) in `read_line?`.

### v0.35.0

  - Add traces provider for `Protocol::HTTP1::Connection`.

### v0.34.1

  - Fix connection state handling to allow idempotent response body closing.
  - Add `kisaten` fuzzing integration for improved security testing.

### v0.34.0

  - Support empty header values in HTTP parsing for better compatibility.

### v0.33.0

  - Support high-byte characters in HTTP headers for improved international compatibility.

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
