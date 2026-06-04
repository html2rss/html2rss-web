# Releases

## v0.62.1

  - Fix handling of `Stream#read(0)`, it must return a mutable string (or clear the given buffer).

## v0.61.0

  - Introduce `Protocol::HTTP::RefusedError` for indicating a stream or request was refused before processing and can be safely retried. `RequestRefusedError` is provided as an alias for backwards compatibility.

## v0.60.0

  - Expose `Protocol::HTTP::Body::Writable#count` attribute to provide access to the number of chunks written to the body.

## v0.59.0

  - Introduce `Protocol::HTTP::Middleware.load` method for loading middleware applications from files.
  - Prevent `ZLib::BufError` when deflating empty chunks by skipping deflation for empty chunks.

## v0.58.1

  - `Protocol::HTTP::DuplicateHeaderError` now includes the existing and new values for better debugging.

## v0.58.0

  - Move trailer validation to `Headers#add` method to ensure all additions are checked at the time of addition as this is a hard requirement.
  - Introduce `Headers#header` method to enumerate only the main headers, excluding trailers. This can be used after invoking `Headers#trailer!` to avoid race conditions.
  - Fix `Headers#to_h` so that indexed headers are not left in an inconsistent state if errors occur during processing.

## v0.57.0

  - Always use `#parse` when parsing header values from strings to ensure proper normalization and validation.
  - Introduce `Protocol::HTTP::InvalidTrailerError` which is raised when a trailer header is not allowed by the current policy.
  - **Breaking**: `Headers#each` now yields parsed values according to the current policy. For the previous behaviour, use `Headers#fields`.

## v0.56.0

  - Introduce `Header::*.parse(value)` which parses a raw header value string into a header instance.
  - Introduce `Header::*.coerce(value)` which coerces any value (`String`, `Array`, etc.) into a header instance with normalization.
  - `Header::*#initialize` now accepts arrays without normalization for efficiency, or strings for backward compatibility.
  - Update `Headers#[]=` to use `coerce(value)` for smart conversion of user input.
  - Normalization (e.g., lowercasing) is applied by `parse`, `coerce`, and `<<` methods, but not by `new` when given arrays.

## v0.55.0

  - **Breaking**: Move `Protocol::HTTP::Header::QuotedString` to `Protocol::HTTP::QuotedString` for better reusability.
  - **Breaking**: Handle cookie key/value pairs using `QuotedString` as per RFC 6265.
      - Don't use URL encoding for cookie key/value.
  - **Breaking**: Remove `Protocol::HTTP::URL` and `Protocol::HTTP::Reference` – replaced by `Protocol::URL` gem.
      - `Protocol::HTTP::URL` -\> `Protocol::URL::Encoding`.
      - `Protocol::HTTP::Reference` -\> `Protocol::URL::Reference`.

## v0.54.0

  - Introduce rich support for `Header::Digest`, `Header::ServerTiming`, `Header::TE`, `Header::Trailer` and `Header::TransferEncoding`.

### Improved HTTP Trailer Security

This release introduces significant security improvements for HTTP trailer handling, addressing potential HTTP request smuggling vulnerabilities by implementing a restrictive-by-default policy for trailer headers.

  - **Security-by-default**: HTTP trailers are now validated and restricted by default to prevent HTTP request smuggling attacks.
  - Only safe headers are permitted in trailers:
      - `date` - Response generation timestamps (safe metadata)
      - `digest` - Content integrity verification (safe metadata)
      - `etag` - Cache validation tags (safe metadata)
      - `server-timing` - Performance metrics (safe metadata)
  - All other trailers are ignored by default.

If you are using this library for gRPC, you will need to use a custom policy to allow the `grpc-status` and `grpc-message` trailers:

``` ruby
module GRPCStatus
	def self.new(value)
		Integer(value)
	end
	
	def self.trailer?
		true
	end
end

module GRPCMessage
	def self.new(value)
		value
	end
	
	def self.trailer?
		true
	end
end

GRPC_POLICY = Protocol::HTTP::Headers::POLICY.dup
GRPC_POLICY["grpc-status"] = GRPCStatus
GRPC_POLICY["grpc-message"] = GRPCMessage

# Reinterpret the headers using the new policy:
response.headers.policy = GRPC_POLICY
response.headers["grpc-status"] # => 0
response.headers["grpc-message"] # => "OK"
```

## v0.53.0

  - Improve consistency of Body `#inspect`.
  - Improve `as_json` support for Body wrappers.

## v0.52.0

  - Add `Protocol::HTTP::Headers#to_a` method that returns the fields array, providing compatibility with standard Ruby array conversion pattern.
  - Expose `tail` in `Headers.new` so that trailers can be accurately reproduced.
  - Add agent context.

## v0.51.0

  - `Protocol::HTTP::Headers` now raise a `DuplicateHeaderError` when a duplicate singleton header (e.g. `content-length`) is added.
  - `Protocol::HTTP::Headers#add` now coerces the value to a string when adding a header, ensuring consistent behaviour.
  - `Protocol::HTTP::Body::Head.for` now accepts an optional `length` parameter, allowing it to create a head body even when the body is not provided, based on the known content length.

## v0.50.0

    - Drop support for Ruby v3.1.

## v0.48.0

  - Add support for parsing `accept`, `accept-charset`, `accept-encoding` and `accept-language` headers into structured values.

## v0.46.0

  - Add support for `priority:` header.

## v0.33.0

  - Clarify behaviour of streaming bodies and copy `Protocol::Rack::Body::Streaming` to `Protocol::HTTP::Body::Streamable`.
  - Copy `Async::HTTP::Body::Writable` to `Protocol::HTTP::Body::Writable`.

## v0.31.0

  - Ensure chunks are flushed if required, when streaming.

## v0.30.0

### `Request[]` and `Response[]` Keyword Arguments

The `Request[]` and `Response[]` methods now support keyword arguments as a convenient way to set various positional arguments.

``` ruby
# Request keyword arguments:
client.get("/", headers: {"accept" => "text/html"}, authority: "example.com")

# Response keyword arguments:
def call(request)
	return Response[200, headers: {"content-Type" => "text/html"}, body: "Hello, World!"]
end
```

### Interim Response Handling

The `Request` class now exposes a `#interim_response` attribute which can be used to handle interim responses both on the client side and server side.

On the client side, you can pass a callback using the `interim_response` keyword argument which will be invoked whenever an interim response is received:

``` ruby
client = ...

interim_response = proc do |status, headers|
	puts "Received interim response: #{status} -> #{headers.inspect}"
end

response = client.get("/index", interim_response: interim_response)
```

On the server side, you can send an interim response using the `#send_interim_response` method:

``` ruby
def call(request)
	if request.headers["expect"] == "100-continue"
		# Send an interim response:
		request.send_interim_response(100)
	end
	
	# ...
end
```

## v0.29.0

  - Introduce `rewind` and `rewindable?` methods for body rewinding capabilities.
  - Add support for output buffer in `read_partial`/`readpartial` methods.
  - `Reader#buffered!` now returns `self` for method chaining.

## v0.28.0

  - Add convenient `Reader#buffered!` method to buffer the body.
  - Modernize gem infrastructure with RuboCop integration.

## v0.27.0

  - Expand stream interface to support `gets`/`puts` operations.
  - Skip empty key/value pairs in header processing.
  - Prefer lowercase method names for consistency.
  - Add `as_json` support to avoid default Rails implementation.
  - Use `@callback` to track invocation state.
  - Drop `base64` gem dependency.

## v0.26.0

  - Prefer connection `close` over `keep-alive` when both are present.
  - Add support for `#readpartial` method.
  - Add `base64` dependency.

## v0.25.0

  - Introduce explicit support for informational responses (1xx status codes).
  - Add `cache-control` support for `must-revalidate`, `proxy-revalidate`, and `s-maxage` directives.
  - Add `#strong_match?` and `#weak_match?` methods to `ETags` header.
  - Fix `last-modified`, `if-modified-since` and `if-unmodified-since` headers to use proper `Date` parsing.
  - Improve date/expires header parsing.
  - Add tests for `Stream#close_read`.
  - Check if input is closed before raising `IOError`.
  - Ensure saved files truncate existing file by default.

## v0.24.0

  - Add output stream `#<<` as alias for `#write`.
  - Add support for `Headers#include?` and `#key?` methods.
  - Fix URL unescape functionality.
  - Fix cookie parsing issues.
  - Fix superclass mismatch in `Protocol::HTTP::Middleware::Builder`.
  - Allow trailers without explicit `trailer` header.
  - Fix cookie handling and Ruby 2 keyword arguments.

## v0.23.0

  - Improve argument handling.
  - Rename `path` parameter to `target` to better match RFCs.

## v0.22.0

  - Rename `trailers` to `trailer` for consistency.

## v0.21.0

  - Streaming interface improvements.
  - Rename `Streamable` to `Completable`.

## v0.20.0

  - Improve `Authorization` header implementation.

## v0.19.0

  - Expose `Body#ready?` for more efficient response handling.

## v0.18.0

  - Add `#trailers` method which enumerates trailers without marking tail.
  - Don't clear trailers in `#dup`, move functionality to `flatten!`.
  - All requests and responses must have mutable headers instance.

## v0.17.0

  - Remove deferred headers due to complexity.
  - Remove deprecated `Headers#slice!`.
  - Add support for static, dynamic and streaming content to `cache-control` model.
  - Initial support for trailers.
  - Add support for `Response#not_modified?`.

## v0.16.0

  - Add support for `if-match` and `if-none-match` headers.
  - Revert `Request#target` change for HTTP/2 compatibility.

## v0.15.0

  - Prefer `Request#target` over `Request#path`.
  - Add body implementation to support HEAD requests.
  - Add support for computing digest on buffered body.
  - Add `Headers#set(key, value)` to replace existing values.
  - Add support for `vary` header.
  - Add support for `no-cache` & `no-store` cache directives.

## v0.14.0

  - Add `Cacheable` body for buffering and caching responses.
  - Add support for `cache-control` header.

## v0.13.0

  - Add support for `connection` header.
  - Fix handling of keyword arguments.

## v0.12.0

  - Improved handling of `cookie` header.
  - Add `Headers#clear` method.

## v0.11.0

  - Ensure `Body#call` invokes `stream.close` when done.

## v0.10.0

  - Allow user to specify size for character devices.

## v0.9.1

  - Add support for `authorization` header.

## v0.8.0

  - Remove `reason` from `Response`.

## v0.7.0

  - Explicit path handling in `Reference#with`.

## v0.6.0

  - Initial version with basic HTTP protocol support.

## v0.5.1

  - Fix path splitting behavior when path is empty.
  - Add `connect` method.
  - Support protocol in `[]` constructor.
  - Incorporate middleware functionality.

## v0.4.0

  - Add `Request`, `Response` and `Body` classes from `async-http`.
  - Allow deletion of non-existent header fields.

## v0.3.0

  - **Initial release** of `protocol-http` gem.
  - Initial implementation of HTTP/2 flow control.
  - Support for connection preface and settings frames.
  - Initial headers support.
  - Implementation of `Connection`, `Client` & `Server` classes.
  - HTTP/2 protocol framing and headers.
