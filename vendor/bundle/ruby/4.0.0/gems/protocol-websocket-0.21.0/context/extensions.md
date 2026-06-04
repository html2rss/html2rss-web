# Extensions

This guide explains how to use `protocol-websocket` for implementing a websocket client and server using extensions.

## Per-message Deflate

WebSockets have a mechanism for implementing extensions. At the time of writing, the only published extension is `permessage-deflate` for per-message compression. It operates on complete messages rather than individual frames.

Clients and servers can negotiate a set of extensions to use. The server can accept or reject these extensions. The client can then instantiate the extensions and apply them to the connection. More specifically, clients need to define a set of extensions they want to support:

~~~ ruby
require 'protocol/websocket'
require 'protocol/websocket/extensions'

client_extensions = Protocol::WebSocket::Extensions::Client.new([
	[Protocol::WebSocket::Extension::Compression, {}]
])

offer_headers = []

client_extensions.offer do |header|
	offer_headers << header.join(';')
end

offer_headers # => ["permessage-deflate;client_max_window_bits"]
~~~

This is transmitted to the server via the `Sec-WebSocket-Extensions` header. The server processes this and returns a subset of accepted extensions. The client receives a list of accepted extensions and instantiates them:

~~~ ruby
server_extensions = Protocol::WebSocket::Extensions::Server.new([
	[Protocol::WebSocket::Extension::Compression, {}]
])

accepted_headers = []

server_extensions.accept(offer_headers) do |header|
	accepted_headers << header.join(';')
end

accepted_headers # => ["permessage-deflate;client_max_window_bits=15"]

client_extensions.accept(accepted_headers)
~~~

We can check the extensions are accepted:

~~~ ruby
server_extensions.accepted
# => [[Protocol::WebSocket::Extension::Compression, {:client_max_window_bits=>15}]]

client_extensions.accepted
# => [[Protocol::WebSocket::Extension::Compression, {:client_max_window_bits=>15}]]
~~~

Once the extensions are negotiated, they can be applied to the connection:

~~~ ruby
require 'protocol/websocket/connection'
require 'socket'

sockets = Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)

client = Protocol::WebSocket::Connection.new(Protocol::WebSocket::Framer.new(sockets.first))
server = Protocol::WebSocket::Connection.new(Protocol::WebSocket::Framer.new(sockets.last))

client_extensions.apply(client)
server_extensions.apply(server)

# We can see that the appropriate wrappers have been added to the connections:
client.reader.class # => Protocol::WebSocket::Extension::Compression::Inflate
client.writer.class # => Protocol::WebSocket::Extension::Compression::Deflate
server.reader.class # => Protocol::WebSocket::Extension::Compression::Inflate
server.writer.class # => Protocol::WebSocket::Extension::Compression::Deflate

client.send_text("Hello World")
# => #<Protocol::WebSocket::TextFrame:0x000000011d555460 @finished=true, @flags=4, @length=13, @mask=nil, @opcode=1, @payload="\xF2H\xCD\xC9\xC9W\b\xCF/\xCAI\x01\x00">

server.read
# => #<Protocol::WebSocket::TextMessage:0x000000011e1e5248 @buffer="Hello World">
~~~

It's possible to disable compression on a per-message basis:

~~~ ruby
client.send_text("Hello World", compress: false)
# => #<Protocol::WebSocket::TextFrame:0x00000001028945b0 @finished=true, @flags=0, @length=11, @mask=nil, @opcode=1, @payload="Hello World">

server.read
# => #<Protocol::WebSocket::TextMessage:0x000000011e77eb50 @buffer="Hello World">
~~~
