# Releases

## v0.17.2

  - When the unix path is bigger than what can fit into `struct sockaddr_un`, a shorter temporary path will be used instead and a symlink created at the original path.

## v0.17.1

  - Add `#to_s` and `#inspect` for `IO::Endpoint::NamedEndpoints`.

## v0.17.0

  - Added `IO::Endpoint::NamedEndpoints` for accessing endpoints by symbolic names, useful for running applications on multiple endpoints with different configurations.

## v0.16.0

  - Improved error handling in `#connect` for more robust connection handling.
  - Added getting started guide and improved documentation coverage.

## v0.15.2

  - Fixed `UNIXEndpoint#bind` to pass all arguments through to super.

## v0.15.1

  - Added `async-dns` to externals and restored removed method.

## v0.15.0

  - Allow wrapper to be customized using endpoint `options[:wrapper]`.
  - Expose wrapper extension points for `connect` and `accept`.

## v0.14.0

  - Uniform `#to_s` and `#inspect` implementations across all endpoints.

## v0.13.1

  - Fixed state leak between iterations of the accept loop.

## v0.13.0

  - Propagate options assigned to composite endpoint to nested endpoints.

## v0.12.0

  - Expose `size` and internal endpoints for composite endpoint.

## v0.10.3

  - Fixed `SSLServer#accept` failures causing accept loop to exit. (\#10)

## v0.10.2

  - Centralized usage of `listen` to wrapper.

## v0.10.1

  - Ensure `listen` is called.

## v0.10.0

  - Don't hardcode timeout support - detect at run-time.

## v0.9.0

  - Correctly set `sync_close`. (\#7)

## v0.8.1

  - Remove broken `require_relative 'readable'`.

## v0.8.0

  - Removed `IO#readable?` dependency in favor of `io-stream` gem.

## v0.7.2

  - Added missing `SSLSocket#remote_address`.

## v0.7.1

  - Improved shims for `IO#readable?`.

## v0.7.0

  - Fixed shim for `OpenSSL::SSL::SSLSocket#local_address`.
  - Added shim for `IO#readable?`.

## v0.6.0

  - Allow `Wrapper#accept` to ignore unknown options.

## v0.5.0

  - Fixed the OpenSSL shims. (\#5)
  - Simplified implementation and separated connected/bound options. (\#4)

## v0.4.0

  - Improved compatibility with `async-http`/`async-io`. (\#3)

## v0.3.0

  - Fixed OpenSSL integration. (\#2)

## v0.2.0

  - Added option `buffered:` for controlling `TCP_NODELAY`.

## v0.1.0

  - Initial implementation extracted from `async-io`.
  - Added support for thread and fiber wrappers.
  - Support Ruby 2.7+ with optional `set_timeout`.
