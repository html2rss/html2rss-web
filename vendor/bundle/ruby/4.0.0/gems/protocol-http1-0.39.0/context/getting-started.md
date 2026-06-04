# Getting Started

This guide explains how to get started with `protocol-http1`, a low-level implementation of the HTTP/1 protocol for building HTTP clients and servers.

## Installation

Add the gem to your project:

```bash
$ bundle add protocol-http1
```

## Core Concepts

`protocol-http1` provides a low-level implementation of the HTTP/1 protocol with several core concepts:

- A {ruby Protocol::HTTP1::Connection} which represents the main entry point for creating HTTP/1.1 clients and servers.
- Integration with the `Protocol::HTTP::Body` classes for handling request and response bodies.

## Usage

`protocol-http1` can be used to build both HTTP clients and servers.

### HTTP Server

Here's a simple HTTP/1.1 server that responds to all requests with "Hello World":

```ruby
#!/usr/bin/env ruby

require "socket"
require "protocol/http1/connection"
require "protocol/http/body/buffered"

# Test with: curl http://localhost:8080/

Addrinfo.tcp("0.0.0.0", 8080).listen do |server|
	loop do
		client, address = server.accept
		connection = Protocol::HTTP1::Connection.new(client)
		
		# Read request:
		while request = connection.read_request
			authority, method, path, version, headers, body = request
			
			# Write response:
			connection.write_response(version, 200, [["content-type", "text/plain"]])
			connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(["Hello World"]))
			
			break unless connection.persistent
		end
	end
end
```

The server:

1. Creates a new {ruby Protocol::HTTP1::Connection} for each client connection.
2. Reads incoming requests using `read_request`.
3. Sends responses using `write_response` and `write_body`.
4. Supports persistent connections by checking `connection.persistent`.

### HTTP Client

Here's a simple HTTP/1.1 client that makes multiple requests:

```ruby
#!/usr/bin/env ruby

require "async"
require "async/http/endpoint"
require "protocol/http1/connection"

Async do
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:8080")
	
	peer = endpoint.connect
	
	puts "Connected to #{peer} #{peer.remote_address.inspect}"
	
	# IO Buffering...
	client = Protocol::HTTP1::Connection.new(peer)
	
	puts "Writing request..."
	3.times do
		client.write_request("localhost", "GET", "/", "HTTP/1.1", [["Accept", "*/*"]])
		client.write_body("HTTP/1.1", nil)
		
		puts "Reading response..."
		response = client.read_response("GET")
		version, status, reason, headers, body = response
		
		puts "Got response: #{response.inspect}"
		puts body&.read
	end
	
	puts "Closing client..."
	client.close
end
```

The client:

1. Creates a connection to a server using `Async::HTTP::Endpoint`.
2. Creates a {ruby Protocol::HTTP1::Connection} wrapper around the socket.
3. Sends requests using `write_request` and `write_body`.
4. Reads responses using `read_response`.
5. Properly closes the connection when done.

### Connection Management

The {ruby Protocol::HTTP1::Connection} handles:

- **Request/Response Parsing**: Automatically parses HTTP/1.1 request and response formats.
- **Persistent Connections**: Supports HTTP/1.1 keep-alive for multiple requests over one connection.
- **Body Handling**: Integrates with `Protocol::HTTP::Body` classes for streaming and buffered content.
- **Header Management**: Properly handles HTTP headers as arrays of key-value pairs.
