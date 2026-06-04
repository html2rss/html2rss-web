# Request and Response Handling

This guide explains how to work with requests and responses when bridging between Rack and `Protocol::HTTP`, covering advanced use cases and edge cases.

## Request Conversion

The {ruby Protocol::Rack::Request} class converts Rack environment hashes into rich `Protocol::HTTP` request objects, providing access to modern HTTP features while maintaining compatibility with Rack.

### Basic Request Access

```ruby
require "protocol/rack/request"

run do |env|
	request = Protocol::Rack::Request[env]
	
	# Access request properties:
	puts request.method         # "GET", "POST", etc.
	puts request.path           # "/users/123"
	puts request.url_scheme     # "http" or "https"
	puts request.authority      # "example.com:80"
end
```

### Headers

Headers are automatically extracted from Rack's `HTTP_*` environment variables:

```ruby
run do |env|
	request = Protocol::Rack::Request[env]
	
	# Headers are available as a `Protocol::HTTP::Headers` object:
	user_agent = request.headers["user-agent"]
	content_type = request.headers["content-type"]
	
	# Headers are case-insensitive:
	user_agent = request.headers["User-Agent"]  # Same as above
end
```

The adapter converts Rack's `HTTP_ACCEPT_ENCODING` format to standard HTTP header names (`accept-encoding`).

### Request Body

The request body is wrapped in a `Protocol::HTTP`-compatible interface:

```ruby
run do |env|
	request = Protocol::Rack::Request[env]
	
	# Read the entire body:
	body = request.body.read
	
	# Or stream it:
	request.body.each do |chunk|
		process_chunk(chunk)
	end
	
	# The body supports rewind if the underlying Rack input supports it:
	request.body.rewind
end
```

The body wrapper handles Rack's `rack.input` interface, which may or may not support `rewind` depending on the server.

### Query Parameters

Query parameters are parsed from the request path:

```ruby
run do |env|
	request = Protocol::Rack::Request[env]
	
	# Access query string:
	query = request.query  # "name=value&other=123"
	
	# Parse query parameters (if using a helper):
	params = URI.decode_www_form(query).to_h
end
```

### Protocol Upgrades

The adapter handles protocol upgrade requests (like WebSockets):

```ruby
run do |env|
	request = Protocol::Rack::Request[env]
	
	# Check for upgrade protocols:
	if protocols = request.protocol
		# protocols is an array: ["websocket"]:
		if protocols.include?("websocket")
			# Handle WebSocket upgrade.
		end
	end
end
```

Protocols are extracted from either `rack.protocol` or the `HTTP_UPGRADE` header.

## Response Conversion

The {ruby Protocol::Rack::Response} class and {ruby Protocol::Rack::Adapter.make_response} handle converting `Protocol::HTTP` responses back to Rack format.

### Basic Response

```ruby
require "protocol/rack/adapter"

run do |env|
	request = Protocol::Rack::Request[env]
	
	# Create a `Protocol::HTTP` response:
	response = Protocol::HTTP::Response[
		200,
		{"content-type" => "text/html"},
		["<h1>Hello</h1>"]
	]
	
	# Convert to Rack format:
	Protocol::Rack::Adapter.make_response(env, response)
end
```

### Response Bodies

The adapter handles different types of response bodies:

#### Enumerable Bodies

```ruby
# Array bodies:
response = Protocol::HTTP::Response[
	200,
	{"content-type" => "text/plain"},
	["Hello", " ", "World"]
]

# Enumerable bodies:
response = Protocol::HTTP::Response[
	200,
	{"content-type" => "text/plain"},
	Enumerator.new do |yielder|
		yielder << "Chunk 1\n"
		yielder << "Chunk 2\n"
	end
]
```

#### Streaming Bodies

```ruby
# Streaming response body:
body = Protocol::HTTP::Body::Buffered.new(["Streaming content"])

response = Protocol::HTTP::Response[
	200,
	{"content-type" => "text/plain"},
	body
]
```

#### File Bodies

```ruby
# File-based responses:
body = Protocol::HTTP::Body::File.open("path/to/file.txt")

response = Protocol::HTTP::Response[
	200,
	{"content-type" => "text/plain"},
	body
]
```

### HEAD Requests

The adapter automatically handles HEAD requests by removing response bodies:

```ruby
run do |env|
	request = Protocol::Rack::Request[env]
	
	# Create a response with a body:
	response = Protocol::HTTP::Response[
		200,
		{"content-type" => "text/html"},
		["<h1>Full Response</h1>"]
	]
	
	# For HEAD requests, the body is automatically removed:
	Protocol::Rack::Adapter.make_response(env, response)
end
```

### Status Codes Without Bodies

Certain status codes (204 No Content, 205 Reset Content, 304 Not Modified) should not include response bodies. The adapter handles this automatically:

```ruby
response = Protocol::HTTP::Response[
	204,  # No Content
	{},
	["This body will be removed"]
]

# The adapter automatically removes the body for 204 responses.
```

### Rack-Specific Features

#### Hijacking

Rack supports response hijacking, which allows taking over the connection:

```ruby
# In a Rack application:
[200, {"rack.hijack" => proc{|io| io.write("Hijacked!")}}, []]

# The adapter handles hijacking automatically using streaming responses.
```

#### Response Finished Callbacks

Rack 2+ supports `rack.response_finished` callbacks:

```ruby
env["rack.response_finished"] ||= []
env["rack.response_finished"] << proc do |env, status, headers, error|
	# Cleanup or logging after response is sent
	puts "Response finished: #{status}"
end
```

The adapter invokes these callbacks in reverse order of registration, as specified by the Rack specification.

### Hop Headers

HTTP hop-by-hop headers (like `Connection`, `Transfer-Encoding`) are automatically removed from responses, as they should not be forwarded through proxies:

```ruby
response = Protocol::HTTP::Response[
	200,
	{
		"content-type" => "text/plain",
		"connection" => "close",          # This will be removed
		"transfer-encoding" => "chunked"  # This will be removed
	},
	["Body"]
]
```
