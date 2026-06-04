# Getting Started

This guide explains how to get started with `protocol-rack` and integrate Rack applications with `Protocol::HTTP` servers.

## Installation

Add the gem to your project:

```bash
$ bundle add protocol-rack
```

## Core Concepts

`protocol-rack` provides a bridge between two HTTP ecosystems:

- **Rack**: The standard Ruby web server interface used by frameworks like Rails, Sinatra, and Roda.
- **`Protocol::HTTP`**: A modern, asynchronous HTTP protocol implementation used by servers like Falcon and Async.

The library enables bidirectional integration:

- **Application Adapter**: Run existing Rack applications on `Protocol::HTTP` servers (like Falcon).
- **Server Adapter**: Run `Protocol::HTTP` applications on Rack-compatible servers (like Puma).

## Usage

The most common use case is running a Rack application on an asynchronous `Protocol::HTTP` server like [falcon](https://github.com/socketry/falcon). This allows you to leverage the performance benefits of async I/O while using your existing Rack-based application code.

### Running a Rack Application

When you have an existing Rack application (like a Rails app, Sinatra app, or any app that follows the Rack specification), you can adapt it to run on `Protocol::HTTP` servers:

```ruby
require "async"
require "async/http/server"
require "async/http/endpoint"
require "protocol/rack/adapter"

# Your existing Rack application:
app = proc do |env|
	[200, {"content-type" => "text/plain"}, ["Hello World"]]
end

# Create an adapter:
middleware = Protocol::Rack::Adapter.new(app)

# Run on an async server:
Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")
	server = Async::HTTP::Server.new(middleware, endpoint)
	server.run
end
```

The adapter automatically detects your Rack version (v2, v3, or v3.1+) and uses the appropriate implementation, ensuring compatibility without any configuration.

### Server Adapter

Any Rack compatible server can host `Protocol::HTTP` compatible middlewares.

``` ruby
require "protocol/http/middleware"
require "protocol/rack"

# Your native application:
middleware = Protocol::HTTP::Middleware::HelloWorld

run do |env|
	# Convert the rack request to a compatible rich request object:
	request = Protocol::Rack::Request[env]
	
	# Call your application
	response = middleware.call(request)
	
	Protocol::Rack::Adapter.make_response(env, response)
end
```
