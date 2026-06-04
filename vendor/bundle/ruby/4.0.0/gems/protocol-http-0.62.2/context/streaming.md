# Streaming

This guide gives an overview of how to implement streaming requests and responses.

## Independent Uni-directional Streaming

The request and response body work independently of each other can stream data in both directions. {ruby Protocol::HTTP::Body::Stream} provides an interface to merge these independent streams into an IO-like interface.

```ruby
#!/usr/bin/env ruby

require "async"
require "async/http/client"
require "async/http/server"
require "async/http/endpoint"

require "protocol/http/body/stream"
require "protocol/http/body/writable"

endpoint = Async::HTTP::Endpoint.parse("http://localhost:3000")

Async do
	server = Async::HTTP::Server.for(endpoint) do |request|
		output = Protocol::HTTP::Body::Writable.new
		stream = Protocol::HTTP::Body::Stream.new(request.body, output)
		
		Async do
			# Simple echo server:
			while chunk = stream.readpartial(1024)
				stream.write(chunk)
			end
		rescue EOFError
			# Ignore EOF errors.
		ensure
			stream.close
		end
		
		Protocol::HTTP::Response[200, {}, output]
	end
	
	server_task = Async{server.run}
	
	client = Async::HTTP::Client.new(endpoint)
	
	input = Protocol::HTTP::Body::Writable.new
	response = client.get("/", body: input)
	
	begin
		stream = Protocol::HTTP::Body::Stream.new(response.body, input)
		
		stream.write("Hello, ")
		stream.write("World!")
		stream.close_write
		
		while chunk = stream.readpartial(1024)
			puts chunk
		end
	rescue EOFError
		# Ignore EOF errors.
	ensure
		stream.close
	end
ensure
	server_task.stop
end
```

This approach works quite well, especially when the input and output bodies are independently compressed, decompressed, or chunked. However, some protocols, notably, WebSockets operate on the raw connection and don't require this level of abstraction.

## Bi-directional Streaming

While WebSockets can work on the above streaming interface, it's a bit more convenient to use the streaming interface directly, which gives raw access to the underlying stream where possible.

```ruby
#!/usr/bin/env ruby

require "async"
require "async/http/client"
require "async/http/server"
require "async/http/endpoint"

require "protocol/http/body/stream"
require "protocol/http/body/writable"

endpoint = Async::HTTP::Endpoint.parse("http://localhost:3000")

Async do
	server = Async::HTTP::Server.for(endpoint) do |request|
		streamable = Protocol::HTTP::Body::Streamable.
		output = Protocol::HTTP::Body::Writable.new
		stream = Protocol::HTTP::Body::Stream.new(request.body, output)
		
		Async do
			# Simple echo server:
			while chunk = stream.readpartial(1024)
				stream.write(chunk)
			end
		rescue EOFError
			# Ignore EOF errors.
		ensure
			stream.close
		end
		
		Protocol::HTTP::Response[200, {}, output]
	end
	
	server_task = Async{server.run}
	
	client = Async::HTTP::Client.new(endpoint)
	
	input = Protocol::HTTP::Body::Writable.new
	response = client.get("/", body: input)
	
	begin
		stream = Protocol::HTTP::Body::Stream.new(response.body, input)
		
		stream.write("Hello, ")
		stream.write("World!")
		stream.close_write
		
		while chunk = stream.readpartial(1024)
			puts chunk
		end
	rescue EOFError
		# Ignore EOF errors.
	ensure
		stream.close
	end
ensure
	server_task.stop
end
```
