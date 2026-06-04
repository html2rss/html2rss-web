# Getting Started

This guide explains how to use `protocol-http` for building abstract HTTP interfaces.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add protocol-http
~~~

## Core Concepts

`protocol-http` has several core concepts:

  - A {ruby Protocol::HTTP::Request} instance which represents an abstract HTTP request. Specific versions of HTTP may subclass this to track additional state.
  - A {ruby Protocol::HTTP::Response} instance which represents an abstract HTTP response. Specific versions of HTTP may subclass this to track additional state.
  - A {ruby Protocol::HTTP::Middleware} interface for building HTTP applications.
  - A {ruby Protocol::HTTP::Headers} interface for storing HTTP headers with semantics based on documented specifications (RFCs, etc).
  - A set of {ruby Protocol::HTTP::Body} classes which handle the internal request and response bodies, including bi-directional streaming.

## Integration

This gem does not provide any specific client or server implementation, rather it's used by several other gems.

  - [Protocol::HTTP1](https://github.com/socketry/protocol-http1) & [Protocol::HTTP2](https://github.com/socketry/protocol-http2) which provide client and server implementations.
  - [Async::HTTP](https://github.com/socketry/async-http) which provides connection pooling and concurrency.

## Usage

### Request

{ruby Protocol::HTTP::Request} represents an HTTP request which can be used both server and client-side.

``` ruby
require "protocol/http/request"

# Short form (recommended):
request = Protocol::HTTP::Request["GET", "/index.html", {"accept" => "text/html"}]

# Long form:
headers = Protocol::HTTP::Headers[["accept", "text/html"]]
request = Protocol::HTTP::Request.new("http", "example.com", "GET", "/index.html", "HTTP/1.1", headers)

# Access request properties
request.method           # => "GET"
request.path             # => "/index.html"
request.headers          # => Protocol::HTTP::Headers instance
```

### Response

{ruby Protocol::HTTP::Response} represents an HTTP response which can be used both server and client-side.

``` ruby
require "protocol/http/response"

# Short form (recommended):
response = Protocol::HTTP::Response[200, {"content-type" => "text/html"}, "Hello, World!"]

# Long form:
headers = Protocol::HTTP::Headers["content-type" => "text/html"]
body = Protocol::HTTP::Body::Buffered.wrap("Hello, World!")
response = Protocol::HTTP::Response.new("HTTP/1.1", 200, headers, body)

# Access response properties
response.status          # => 200
response.headers         # => Protocol::HTTP::Headers instance
response.body            # => Body instance

# Status checking methods
response.success?        # => true (200-299)
response.ok?             # => true (200)
response.redirection?    # => false (300-399)
response.failure?        # => false (400-599)
```

### Headers

{ruby Protocol::HTTP::Headers} provides semantically meaningful interpretation of header values and implements case-normalising keys.

#### Basic Usage

``` ruby
require "protocol/http/headers"

headers = Protocol::HTTP::Headers.new

# Assignment by title-case key:
headers["Content-Type"] = "image/jpeg"

# Lookup by lower-case (normalized) key:
headers["content-type"]
# => "image/jpeg"
```

#### Semantic Processing

Many headers receive special semantic processing, automatically splitting comma-separated values and providing structured access:

``` ruby
# Accept header with quality values:
headers["Accept"] = "text/html, application/json;q=0.8, */*;q=0.1"
accept = headers["accept"]
# => ["text/html", "application/json;q=0.8", "*/*;q=0.1"]

# Access parsed media ranges with quality factors:
accept.media_ranges.each do |range|
	puts "#{range.type}/#{range.subtype} (q=#{range.quality_factor})"
end
# text/html (q=1.0)
# application/json (q=0.8)
# */* (q=0.1)

# Accept-Encoding automatically splits values:
headers["Accept-Encoding"] = "gzip, deflate, br;q=0.9"
headers["accept-encoding"]
# => ["gzip", "deflate", "br;q=0.9"]

# Cache-Control splits directives:
headers["Cache-Control"] = "max-age=3600, no-cache, must-revalidate"
headers["cache-control"]
# => ["max-age=3600", "no-cache", "must-revalidate"]

# Vary header normalizes field names to lowercase:
headers["Vary"] = "Accept-Encoding, User-Agent"
headers["vary"]
# => ["accept-encoding", "user-agent"]
```
