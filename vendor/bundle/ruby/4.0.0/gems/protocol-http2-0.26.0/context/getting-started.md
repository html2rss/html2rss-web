# Getting Started

This guide explains how to use the `protocol-http2` gem to implement a basic HTTP/2 client.

## Installation

Add the gem to your project:

``` bash
$ bundle add protocol-http2
```

## Usage

This gem provides a low-level implementation of the HTTP/2 protocol. It is designed to be used in conjunction with other libraries to provide a complete HTTP/2 client or server. However, it is straight forward to give examples of how to use the library directly.

### Client

Here is a basic HTTP/2 client:

``` ruby
require "async"
require "async/io/stream"
require "async/http/endpoint"
require "protocol/http2/client"

Async do
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com/search?q=kittens")
	
	peer = endpoint.connect
	
	puts "Connected to #{peer.inspect}"
	
	# IO Buffering:
	stream = Async::IO::Stream.new(peer)
	
	framer = Protocol::HTTP2::Framer.new(stream)
	client = Protocol::HTTP2::Client.new(framer)
	
	puts "Sending connection preface..."
	client.send_connection_preface
	
	puts "Creating stream..."
	stream = client.create_stream
	
	headers = [
		[":scheme", endpoint.scheme],
		[":method", "GET"],
		[":authority", "www.google.com"],
		[":path", endpoint.path],
		["accept", "*/*"],
	]
	
	puts "Sending request on stream id=#{stream.id} state=#{stream.state}..."
	stream.send_headers(headers, Protocol::HTTP2::END_STREAM)
	
	puts "Waiting for response..."
	$count = 0
	
	def stream.process_headers(frame)
		headers = super
		puts "Got response headers: #{headers} (#{frame.end_stream?})"
	end
	
	def stream.receive_data(frame)
		data = super
		
		$count += data.scan(/kittens/).count
		
		puts "Got response data: #{data.bytesize}"
	end
	
	until stream.closed?
		frame = client.read_frame
	end
	
	puts "Got #{$count} kittens!"
	
	puts "Closing client..."
	client.close
end
```
