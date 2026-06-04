# Middleware

This guide explains how to build and use HTTP middleware with `Protocol::HTTP::Middleware`.

## Overview

The middleware interface provides a convenient wrapper for implementing HTTP middleware components that can process requests and responses. Middleware enables you to build composable HTTP applications by chaining multiple processing layers.

A middleware instance generally needs to respond to two methods:
- `call(request)` -> `response`.
- `close()` (called when shutting down).

## Basic Middleware Interface

You can implement middleware without using the `Middleware` class by implementing the interface directly:

``` ruby
class SimpleMiddleware
	def initialize(delegate)
		@delegate = delegate
	end
	
	def call(request)
		# Process request here
		response = @delegate.call(request)
		# Process response here
		return response
	end
	
	def close
		@delegate&.close
	end
end
```

## Using the Middleware Class

The `Protocol::HTTP::Middleware` class provides a convenient base for building middleware:

``` ruby
require "protocol/http/middleware"

class LoggingMiddleware < Protocol::HTTP::Middleware
	def call(request)
		puts "Processing: #{request.method} #{request.path}"
		
		response = super  # Calls @delegate.call(request)
		
		puts "Response: #{response.status}"
		return response
	end
end

# Use with a delegate:
app = LoggingMiddleware.new(Protocol::HTTP::Middleware::HelloWorld)
```

## Building Middleware Stacks

Use `Protocol::HTTP::Middleware.build` to construct middleware stacks:

``` ruby
require "protocol/http/middleware"

app = Protocol::HTTP::Middleware.build do
	use LoggingMiddleware
	use CompressionMiddleware
	run Protocol::HTTP::Middleware::HelloWorld
end

# Handle a request:
request = Protocol::HTTP::Request["GET", "/"]
response = app.call(request)
```

The builder works by:
- `use` adds middleware to the stack
- `run` specifies the final application (defaults to `NotFound`)
- Middleware is chained in reverse order (last `use` wraps first)

## Block-Based Middleware

Convert a block into middleware using `Middleware.for`:

``` ruby
middleware = Protocol::HTTP::Middleware.for do |request|
	if request.path == "/health"
		Protocol::HTTP::Response[200, {}, ["OK"]]
	else
		# This would normally delegate, but this example doesn't have a delegate
		Protocol::HTTP::Response[404]
	end
end

request = Protocol::HTTP::Request["GET", "/health"]
response = middleware.call(request)
# => Response with status 200
```

## Built-in Middleware

### HelloWorld

Always returns "Hello World!" response:

``` ruby
app = Protocol::HTTP::Middleware::HelloWorld
response = app.call(request)
# => 200 "Hello World!"
```

### NotFound

Always returns 404 response:

``` ruby
app = Protocol::HTTP::Middleware::NotFound  
response = app.call(request)
# => 404 Not Found
```

### Okay

Always returns 200 response with no body:

``` ruby
app = Protocol::HTTP::Middleware::Okay
response = app.call(request)
# => 200 OK
```

## Real-World Middleware Examples

### Authentication Middleware

``` ruby
class AuthenticationMiddleware < Protocol::HTTP::Middleware
	def initialize(delegate, api_key: nil)
		super(delegate)
		@api_key = api_key
	end
	
	def call(request)
		auth_header = request.headers["authorization"]
		
		unless auth_header == "Bearer #{@api_key}"
			return Protocol::HTTP::Response[401, {}, ["Unauthorized"]]
		end
		
		super
	end
end

# Usage:
app = Protocol::HTTP::Middleware.build do
	use AuthenticationMiddleware, api_key: "secret123"
	run MyApplication
end
```

### Content Type Middleware

``` ruby
class ContentTypeMiddleware < Protocol::HTTP::Middleware
	def call(request)
		response = super
		
		# Add content-type header if not present
		unless response.headers.include?("content-type")
			response.headers["content-type"] = "text/plain"
		end
		
		response
	end
end
```

## Testing Middleware

``` ruby
describe MyMiddleware do
	let(:app) {MyMiddleware.new(Protocol::HTTP::Middleware::Okay)}
	
	it "processes requests correctly" do
		request = Protocol::HTTP::Request["GET", "/test"]
		response = app.call(request)
		
		expect(response.status).to be == 200
	end
	
	it "closes properly" do
		expect{app.close}.not.to raise_exception
	end
end
```
