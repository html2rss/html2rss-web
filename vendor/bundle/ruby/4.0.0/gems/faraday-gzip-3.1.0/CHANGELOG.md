# Changelog

## 3.1.0 (05-Jan-2026)

* Improve handling of edge cases and malformed `Content-Encoding` headers
* Support multiple encodings and respect `identity` responses
* Avoid modifying streaming and non-string response bodies
* Normalize response headers after decompression
* Update and expand test coverage, test with Ruby 4.0

## 3.0.4 (06-Apr-2025)

* Require `StringIO` that might not always be readily available

## 3.0.3 (25-Feb-2025)

* Minor code fixes, make some methods more solid

## 3.0.1 / 3.0.2 (01-Nov-2024)

* Minor fixes in gemspec

## 3.0.0 (29-Oct-2024)

* **Breaking change**: Drop support for Ruby 2, require 3.0+
* **Breaking change**: Drop support for Faraday v1. If you need to support Faraday v1, stay on [faraday-gzip version 2](https://github.com/bodrovis/faraday-gzip/tree/v2).
* Various code tweaks
* Remove JRuby 9.3 from CI matrix

## 2.0.1 (02-Jan-2024)

* Handle cases when body is `nil` (thanks, @bendangelo)

## 2.0.0 (21-Jul-2023)

* Use zlib version 3

## 1.0.0 (27-Dec-2022)

* Added support for JRuby (thanks, @ashkulz)
* Test with Ruby 3.2
* Minor updates

## 0.1.0 (04-Feb-2022)

* First stable release.

## 0.1.0.rc1

* Initial release.