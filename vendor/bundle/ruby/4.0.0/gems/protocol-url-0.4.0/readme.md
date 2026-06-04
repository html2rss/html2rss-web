# Protocol::URL

Provides abstractions for working with URLs.

[![Development Status](https://github.com/socketry/protocol-url/workflows/Test/badge.svg)](https://github.com/socketry/protocol-url/actions?workflow=Test)

## Usage

Please see the [project documentation](https://github.com/socketry/protocol-url) for more details.

  - [Getting Started](https://github.com/socketry/protocol-urlguides/getting-started/index) - This guide explains how to get started with `protocol-url` for parsing, manipulating, and constructing URLs in Ruby.

  - [Working with References](https://github.com/socketry/protocol-urlguides/working-with-references/index) - This guide explains how to use <code class="language-ruby">Protocol::URL::Reference</code> for managing URLs with query parameters and fragments.

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

## Releases

Please see the [project releases](https://github.com/socketry/protocol-urlreleases/index) for all releases.

### v0.4.0

  - Add comparison methods to `Protocol::URL::Relative` (and by inheritance to `Protocol::URL::Absolute`):
      - `#==` for structural equality comparison (compares path, query, fragment components).
      - `#===` for string equality comparison (enables case statement matching).
      - `#<=>` for ordering and sorting.
      - `#hash` for hash key support.
      - `#equal?` for component-based equality checking.
  - Add JSON serialization support to `Protocol::URL::Relative`:
      - `#as_json` returns the string representation.
      - `#to_json` returns a JSON-encoded string.

### v0.3.0

  - Add `relative(target, from)` for computing relative paths between URLs.

### v0.2.0

  - Move `Protocol::URL::PATTERN` to `protocol/url/pattern.rb` so it can be shared more easily.

### v0.1.0

  - Initial implementation.

## See Also

  - [protocol-http](https://github.com/socketry/protocol-http) — HTTP protocol implementation and abstractions.
