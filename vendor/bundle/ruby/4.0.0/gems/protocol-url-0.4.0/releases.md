# Releases

## v0.4.0

  - Add comparison methods to `Protocol::URL::Relative` (and by inheritance to `Protocol::URL::Absolute`):
      - `#==` for structural equality comparison (compares path, query, fragment components).
      - `#===` for string equality comparison (enables case statement matching).
      - `#<=>` for ordering and sorting.
      - `#hash` for hash key support.
      - `#equal?` for component-based equality checking.
  - Add JSON serialization support to `Protocol::URL::Relative`:
      - `#as_json` returns the string representation.
      - `#to_json` returns a JSON-encoded string.

## v0.3.0

  - Add `relative(target, from)` for computing relative paths between URLs.

## v0.2.0

  - Move `Protocol::URL::PATTERN` to `protocol/url/pattern.rb` so it can be shared more easily.

## v0.1.0

  - Initial implementation.
