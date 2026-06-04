# Releases

## v0.22.1

  - Rack 2 should not use `to_ary`.

## v0.22.0

  - Prefer `Protocol::HTTP::Body::Buffered` where possible for enumerable bodies, mainly to avoid creating `Enumerable`s.

## v0.21.1

  - Fix missing `body#close` for streaming bodies.

## v0.21.0

  - For the purpose of constructing the rack request environment, trailers are ignored.

## v0.20.0

  - Convert header values into strings using `to_s` so that `Headers#each` can yield non-string values if necessary.

## v0.19.0

  - Use `Headers#add` instead of `Headers#[]=` in Rack3 and Rack31 adapters, which is the correct interface for appending headers.

## v0.18.0

  - Correctly invoke `rack.response_finished` in reverse order.
  - Tolerate errors during `rack.response_finished` callbacks.

## v0.17.0

  - Support `rack.response_finished` in Rack 2 if it's present in the environment.

## v0.16.0

  - Hijacked IO is no longer duped, as it's not retained by the original connection, and `SSLSocket` does not support duping.

## v0.15.0

  - Use `IO::Stream::Readable` for the input body, which is a better tested and more robust interface.

## v0.14.0

  - Handling of `HEAD` requests is now more robust.

## v0.13.0

  - 100% test and documentation coverage.
  - {Protocol::Rack::Input\#rewind} now works when the entire input is already read.
  - {Protocol::Rack::Adapter::Rack2} has stricter validation of the application response.

## v0.12.0

  - Ignore (and close) response bodies for status codes that don't allow them.

## v0.11.2

  - Stop setting `env["SERVER_PORT"]` to `nil` if not present.
