# Releases

## v0.21.0

  - All frame reading and writing logic has been consolidated into `Framer` to improve performance.

## v0.20.2

  - Fix error messages for `Frame` to be more descriptive.

## v0.20.1

  - Revert masking enforcement option introduced in v0.20.0 due to compatibility issues.

## v0.20.0

  - Introduce option `requires_masking` to `Framer` for enforcing masking on received frames.

## v0.19.1

  - Ensure ping reply payload is packed correctly.

## v0.19.0

  - Default to empty string for message buffer when no data is provided.

## v0.18.0

  - Add `PingMessage` alongside `TextMessage` and `BinaryMessage` for a consistent message interface.
  - Remove `JSONMessage` (use application-level encoding instead).

## v0.17.0

  - Introduce `#close_write` and `#shutdown` methods on `Connection` for more precise connection lifecycle control.

## v0.16.0

  - Move `#send` logic into `Message` for better encapsulation.
  - Improve error handling when a `nil` message is passed.

## v0.15.0

  - Require `Message` class by default.
