# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2023-2024, by Thomas Morgan.
# Copyright, 2024, by Anton Zhuravsky.

require "protocol/http/headers"

require_relative "reason"
require_relative "error"
require_relative "body"

require "protocol/http/body/head"

require "protocol/http/methods"

module Protocol
	module HTTP1
		CONTENT_LENGTH = "content-length"
		
		TRANSFER_ENCODING = "transfer-encoding"
		CHUNKED = "chunked"
		
		CONNECTION = "connection"
		CLOSE = "close"
		KEEP_ALIVE = "keep-alive"
		
		HOST = "host"
		UPGRADE = "upgrade"
		
		# HTTP/1.x request line parser:
		TOKEN = /[!#$%&'*+\-\.\^_`|~0-9a-zA-Z]+/.freeze
		REQUEST_LINE = /\A(#{TOKEN}) ([^\s]+) (HTTP\/\d.\d)\z/.freeze
		
		# HTTP/1.x header parser:
		FIELD_NAME = TOKEN
		OWS = /[ \t]*/
		# A field value is any string of characters that does not contain a null character, CR, or LF. After reflecting on the RFCs and surveying real implementations, I came to the conclusion that the RFCs are too restrictive. Most servers only check for the presence of null bytes, and obviously CR/LF characters have semantic meaning in the parser. So, I decided to follow this defacto standard, even if I'm not entirely happy with it.
		FIELD_VALUE = /[^\0\r\n]+/.freeze
		HEADER = /\A(#{FIELD_NAME}):#{OWS}(?:(#{FIELD_VALUE})#{OWS})?\z/.freeze
		
		VALID_FIELD_NAME = /\A#{FIELD_NAME}\z/.freeze
		VALID_FIELD_VALUE = /\A#{FIELD_VALUE}?\z/.freeze
		
		DEFAULT_MAXIMUM_LINE_LENGTH = 8192
		
		# Represents a single HTTP/1.x connection, which may be used to send and receive multiple requests and responses.
		class Connection
			CRLF = "\r\n"
			
			# The HTTP/1.0 version string.
			HTTP10 = "HTTP/1.0"
			
			# The HTTP/1.1 version string.
			HTTP11 = "HTTP/1.1"
			
			# Initialize the connection with the given stream.
			#
			# @parameter stream [IO] the stream to read and write data from.
			# @parameter persistent [Boolean] whether the connection is persistent.
			# @parameter state [Symbol] the initial state of the connection, typically idle.
			def initialize(stream, persistent: true, state: :idle, maximum_line_length: DEFAULT_MAXIMUM_LINE_LENGTH)
				@stream = stream
				
				@persistent = persistent
				@state = state
				
				@count = 0
				
				@maximum_line_length = maximum_line_length
			end
			
			# The underlying IO stream.
			attr :stream
			
			# @attribute [Boolean] true if the connection is persistent.
			#
			# This determines what connection headers are sent in the response and whether the connection can be reused after the response is sent. This setting is automatically managed according to the nature of the request and response. Changing to false is safe. Changing to true from outside this class should generally be avoided and, depending on the response semantics, may be reset to false anyway.
			attr_accessor :persistent
			
			# The current state of the connection.
			#
			# ```
			#                          ┌────────┐
			#                          │        │
			# ┌───────────────────────►│  idle  │
			# │                        │        │
			# │                        └───┬────┘
			# │                            │
			# │                            │ send request /
			# │                            │ receive request
			# │                            │
			# │                            ▼
			# │                        ┌────────┐
			# │                recv ES │        │ send ES
			# │           ┌────────────┤  open  ├────────────┐
			# │           │            │        │            │
			# │           ▼            └───┬────┘            ▼
			# │      ┌──────────┐          │           ┌──────────┐
			# │      │   half   │          │           │   half   │
			# │      │  closed  │          │ send R /  │  closed  │
			# │      │ (remote) │          │ recv R    │ (local)  │
			# │      └────┬─────┘          │           └─────┬────┘
			# │           │                │                 │
			# │           │ send ES /      │       recv ES / │
			# │           │ close          ▼           close │
			# │           │            ┌────────┐            │
			# │           └───────────►│        │◄───────────┘
			# │                        │ closed │
			# └────────────────────────┤        │
			#         persistent       └────────┘
			# ```
			#
			# - `ES`: the body was fully received or sent (end of stream).
			# - `R`: the connection was closed unexpectedly (reset).
			#
			# State transition methods use a trailing "!".
			attr_accessor :state
			
			# @return [Boolean] whether the connection is in the idle state.
			def idle?
				@state == :idle
			end
			
			# @return [Boolean] whether the connection is in the open state.
			def open?
				@state == :open
			end
			
			# @return [Boolean] whether the connection is in the half-closed local state.
			def half_closed_local?
				@state == :half_closed_local
			end
			
			# @return [Boolean] whether the connection is in the half-closed remote state.
			def half_closed_remote?
				@state == :half_closed_remote
			end
			
			# @return [Boolean] whether the connection is in the closed state.
			def closed?
				@state == :closed
			end
			
			# @attribute [Integer] the number of requests and responses processed by this connection.
			attr :count
			
			# Indicates whether the connection is persistent given the version, method, and headers.
			#
			# @parameter version [String] the HTTP version.
			# @parameter method [String] the HTTP method.
			# @parameter headers [Hash] the HTTP headers.
			# @return [Boolean] whether the connection can be persistent.
			def persistent?(version, method, headers)
				if method == HTTP::Methods::CONNECT
					return false
				end
				
				if version == HTTP10
					if connection = headers[CONNECTION]
						return connection.keep_alive?
					else
						return false
					end
				else # HTTP/1.1+
					if connection = headers[CONNECTION]
						return !connection.close?
					else
						return true
					end
				end
			end
			
			# Write the appropriate header for connection persistence.
			def write_connection_header(version)
				if version == HTTP10
					@stream.write("connection: keep-alive\r\n") if @persistent
				else
					@stream.write("connection: close\r\n") unless @persistent
				end
			end
			
			# Write the appropriate header for connection upgrade.
			def write_upgrade_header(upgrade)
				@stream.write("connection: upgrade\r\nupgrade: #{upgrade}\r\n")
			end
			
			# Indicates whether the connection has been hijacked meaning its IO has been handed over and is not usable anymore.
			#
			# @returns [Boolean] hijack status
			def hijacked?
				@stream.nil?
			end
			
			# Hijack the connection - that is, take over the underlying IO and close the connection.
			#
			# @returns [IO | Nil] the underlying non-blocking IO.
			def hijack!
				@persistent = false
				
				if stream = @stream
					@stream = nil
					stream.flush
					
					@state = :hijacked
					self.closed
					
					return stream
				end
			end
			
			# Close the read end of the connection and transition to the half-closed remote state (or closed if already in the half-closed local state).
			def close_read
				unless @state == :closed
					@persistent = false
					@stream&.close_read
					self.receive_end_stream!
				end
			end
			
			# Close the connection and underlying stream and transition to the closed state.
			def close(error = nil)
				@persistent = false
				
				if stream = @stream
					@stream = nil
					stream.close
				end
				
				unless closed?
					@state = :closed
					self.closed(error)
				end
			end
			
			# Force a transition to the open state.
			#
			# @raises [ProtocolError] if the connection is not in the idle state.
			def open!
				unless @state == :idle
					raise ProtocolError, "Cannot open connection in state: #{@state}!"
				end
				
				@state = :open
				
				return self
			end
			
			# Write a request to the connection. It is expected you will write the body after this method.
			#
			# Transitions to the open state.
			#
			# @parameter authority [String] the authority of the request.
			# @parameter method [String] the HTTP method.
			# @parameter target [String] the request target.
			# @parameter version [String] the HTTP version.
			# @parameter headers [Hash] the HTTP headers.
			# @raises [RefusedError] if the request was not processed.
			def write_request(authority, method, target, version, headers)
				open!
				
				@stream.write("#{method} #{target} #{version}\r\n")
				@stream.write("host: #{authority}\r\n") if authority
				
				write_headers(headers)
			rescue
				raise ::Protocol::HTTP::RefusedError
			end
			
			# Write a response to the connection. It is expected you will write the body after this method.
			#
			# @parameter version [String] the HTTP version.
			# @parameter status [Integer] the HTTP status code.
			# @parameter headers [Hash] the HTTP headers.
			# @parameter reason [String] the reason phrase, defaults to the standard reason phrase for the status code.
			def write_response(version, status, headers, reason = nil)
				reason ||= Reason::DESCRIPTIONS[status]
				
				unless @state == :open or @state == :half_closed_remote
					raise ProtocolError, "Cannot write response in state: #{@state}!"
				end
				
				# Safari WebSockets break if no reason is given:
				@stream.write("#{version} #{status} #{reason}\r\n")
				
				write_headers(headers)
			end
			
			# Write an interim response to the connection. It is expected you will eventually write the final response after this method.
			#
			# @parameter version [String] the HTTP version.
			# @parameter status [Integer] the HTTP status code.
			# @parameter headers [Hash] the HTTP headers.
			# @parameter reason [String] the reason phrase, defaults to the standard reason phrase for the status code.
			# @raises [ProtocolError] if the connection is not in the open or half-closed remote state.
			def write_interim_response(version, status, headers, reason = nil)
				reason ||= Reason::DESCRIPTIONS[status]
				
				unless @state == :open or @state == :half_closed_remote
					raise ProtocolError, "Cannot write interim response in state: #{@state}!"
				end
				
				@stream.write("#{version} #{status} #{reason}\r\n")
				
				write_headers(headers)
				
				@stream.write("\r\n")
				@stream.flush
			end
			
			# Write headers to the connection.
			#
			# @parameter headers [Hash] the headers to write.
			# @raises [BadHeader] if the header name or value is invalid.
			def write_headers(headers)
				headers.each do |name, value|
					# Convert it to a string:
					name = name.to_s
					value = value.to_s
					
					# Validate it:
					unless name.match?(VALID_FIELD_NAME)
						raise BadHeader, "Invalid header name: #{name.inspect}"
					end
					
					unless value.match?(VALID_FIELD_VALUE)
						raise BadHeader, "Invalid header value for #{name}: #{value.inspect}"
					end
					
					# Write it:
					@stream.write("#{name}: #{value}\r\n")
				end
			end
			
			# Read some data from the connection.
			#
			# @parameter length [Integer] the maximum number of bytes to read.
			def readpartial(length)
				@stream.readpartial(length)
			end
			
			# Read some data from the connection.
			#
			# @parameter length [Integer] the number of bytes to read.
			def read(length)
				@stream.read(length)
			end
			
			# Read a line from the connection.
			#
			# @returns [String | Nil] the line read, or nil if the connection is closed.
			# @raises [LineLengthError] if the line is too long.
			# @raises [ProtocolError] if the line is not terminated properly.
			def read_line?
				if line = @stream.gets(CRLF, @maximum_line_length)
					unless line.chomp!(CRLF)
						if line.bytesize == @maximum_line_length
							# This basically means that the request line, response line, header, or chunked length line is too long:
							raise LineLengthError, "Line too long!"
						else
							# This means the line was not terminated properly, which is a protocol violation:
							raise ProtocolError, "Line not terminated properly!"
						end
					end
				end
				
				return line
			# If a connection is shut down abruptly, we treat it as EOF, but only specifically in `read_line?`.
			rescue Errno::ECONNRESET
				return nil
			end
			
			# Read a line from the connection.
			#
			# @raises [EOFError] if a line could not be read.
			# @raises [LineLengthError] if the line is too long.
			def read_line
				read_line? or raise EOFError
			end
			
			# Read a request line from the connection.
			#
			# @returns [Tuple(String, String, String) | Nil] the method, path, and version of the request, or nil if the connection is closed.
			def read_request_line
				return unless line = read_line?
				
				if match = line.match(REQUEST_LINE)
					_, method, path, version = *match
				else
					raise InvalidRequest, line.inspect
				end
				
				return method, path, version
			end
			
			# Read a request from the connection, including the request line and request headers, and prepares to read the request body.
			#
			# Transitions to the open state.
			#
			# @yields {|host, method, path, version, headers, body| ...} if a block is given.
			# @returns [Tuple(String, String, String, String, HTTP::Headers, Protocol::HTTP1::Body) | Nil] the host, method, path, version, headers, and body of the request, or `nil` if the connection is closed.
			# @raises [ProtocolError] if the connection is not in the idle state.
			def read_request
				open!
				
				method, path, version = read_request_line
				return unless method
				
				headers = read_headers
				
				# If we are not persistent, we can't become persistent even if the request might allow it:
				if @persistent
					# In other words, `@persistent` can only transition from true to false.
					@persistent = persistent?(version, method, headers)
				end
				
				body = read_request_body(method, headers)
				
				unless body
					self.receive_end_stream!
				end
				
				@count += 1
				
				if block_given?
					yield headers.delete(HOST), method, path, version, headers, body
				else
					return headers.delete(HOST), method, path, version, headers, body
				end
			end
			
			# Read a response line from the connection.
			#
			# @returns [Tuple(String, Integer, String)] the version, status, and reason of the response.
			# @raises [EOFError] if the connection is closed.
			def read_response_line
				version, status, reason = read_line.split(/\s+/, 3)
				
				status = Integer(status)
				
				return version, status, reason
			end
			
			# Indicates whether the status code is an interim status code.
			#
			# @parameter status [Integer] the status code.
			# @returns [Boolean] whether the status code is an interim status code.
			def interim_status?(status)
				status != 101 and status >= 100 and status < 200
			end
			
			# Read a response from the connection.
			#
			# @parameter method [String] the HTTP method.
			# @yields {|version, status, reason, headers, body| ...} if a block is given.
			# @returns [Tuple(String, Integer, String, HTTP::Headers, Protocol::HTTP1::Body)] the version, status, reason, headers, and body of the response.
			# @raises [ProtocolError] if the connection is not in the open or half-closed local state.
			# @raises [EOFError] if the connection is closed.
			def read_response(method)
				unless @state == :open or @state == :half_closed_local
					raise ProtocolError, "Cannot read response in state: #{@state}!"
				end
				
				version, status, reason = read_response_line
				
				headers = read_headers
				
				if @persistent
					@persistent = persistent?(version, method, headers)
				end
				
				unless interim_status?(status)
					body = read_response_body(method, status, headers)
					
					unless body
						self.receive_end_stream!
					end
					
					@count += 1
				end
				
				if block_given?
					yield version, status, reason, headers, body
				else
					return version, status, reason, headers, body
				end
			end
			
			# Read headers from the connection until an empty line is encountered.
			#
			# @returns [HTTP::Headers] the headers read.
			# @raises [EOFError] if the connection is closed.
			# @raises [BadHeader] if a header could not be parsed.
			def read_headers
				fields = []
				
				while line = read_line
					# Empty line indicates end of headers:
					break if line.empty?
					
					if match = line.match(HEADER)
						fields << [match[1], match[2] || ""]
					else
						raise BadHeader, "Could not parse header: #{line.inspect}"
					end
				end
				
				return HTTP::Headers.new(fields)
			end
			
			# Transition to the half-closed local state, in other words, the connection is closed for writing.
			#
			# If the connection is already in the half-closed remote state, it will transition to the closed state.
			#
			# @raises [ProtocolError] if the connection is not in the open state.
			def send_end_stream!
				if @state == :open
					@state = :half_closed_local
				elsif @state == :half_closed_remote
					self.close!
				else
					raise ProtocolError, "Cannot send end stream in state: #{@state}!"
				end
			end
			
			# Write an upgrade body to the connection.
			#
			# This writes the upgrade header and the body to the connection. If the body is `nil`, you should coordinate writing to the stream.
			#
			# The connection will not be persistent after this method is called.
			# 
			# @parameter protocol [String] the protocol to upgrade to.
			# @parameter body [Object | Nil] the body to write.
			# @returns [IO] the underlying IO stream.
			def write_upgrade_body(protocol, body = nil)
				# Once we upgrade the connection, it can no longer handle other requests:
				@persistent = false
				
				write_upgrade_header(protocol)
				
				@stream.write("\r\n")
				@stream.flush # Don't remove me!
				
				if body
					body.each do |chunk|
						@stream.write(chunk)
						@stream.flush
					end
					
					@stream.close_write
				end
				
				return @stream
			ensure
				self.send_end_stream!
			end
			
			# Write a tunnel body to the connection.
			#
			# This writes the connection header and the body to the connection. If the body is `nil`, you should coordinate writing to the stream.
			#
			# The connection will not be persistent after this method is called.
			#
			# @parameter version [String] the HTTP version.
			# @parameter body [Object | Nil] the body to write.
			# @returns [IO] the underlying IO stream.
			def write_tunnel_body(version, body = nil)
				@persistent = false
				
				write_connection_header(version)
				
				@stream.write("\r\n")
				@stream.flush # Don't remove me!
				
				if body
					body.each do |chunk|
						@stream.write(chunk)
						@stream.flush
					end
					
					@stream.close_write
				end
				
				return @stream
			ensure
				self.send_end_stream!
			end
			
			# Write an empty body to the connection.
			#
			# If given, the body will be closed.
			#
			# @parameter body [Object | Nil] the body to write.
			def write_empty_body(body = nil)
				@stream.write("content-length: 0\r\n\r\n")
				@stream.flush
				
				body&.close
			ensure
				self.send_end_stream!
			end
			
			# Write a fixed length body to the connection.
			#
			# If the request was a `HEAD` request, the body will be closed, and no data will be written.
			#
			# @parameter body [Object] the body to write.
			# @parameter length [Integer] the length of the body.
			# @parameter head [Boolean] whether the request was a `HEAD` request.
			# @raises [ContentLengthError] if the body length does not match the content length specified.
			def write_fixed_length_body(body, length, head)
				@stream.write("content-length: #{length}\r\n\r\n")
				
				if head
					@stream.flush
				else
					@stream.flush unless body.ready?
					
					chunk_length = 0
					# Use a manual read loop (not body.each) so that body.close runs after the response is fully written and flushed. This ensures completion callbacks (e.g. rack.response_finished) don't delay the client.
					while chunk = body.read
						chunk_length += chunk.bytesize
						
						if chunk_length > length
							raise ContentLengthError, "Trying to write #{chunk_length} bytes, but content length was #{length} bytes!"
						end
						
						@stream.write(chunk)
						@stream.flush unless body.ready?
					end
					
					@stream.flush
					
					if chunk_length != length
						raise ContentLengthError, "Wrote #{chunk_length} bytes, but content length was #{length} bytes!"
					end
				end
			rescue => error
				raise
			ensure
				# Close the body after the response is fully flushed, so that completion callbacks run after the client has received the response:
				body.close(error)
				
				self.send_end_stream!
			end
			
			# Write a chunked body to the connection.
			#
			# If the request was a `HEAD` request, the body will be closed, and no data will be written.
			#
			# If trailers are given, they will be written after the body.
			#
			# @parameter body [Object] the body to write.
			# @parameter head [Boolean] whether the request was a `HEAD` request.
			# @parameter trailer [Hash | Nil] the trailers to write.
			def write_chunked_body(body, head, trailer = nil)
				@stream.write("transfer-encoding: chunked\r\n\r\n")
				
				if head
					@stream.flush
				else
					@stream.flush unless body.ready?
					
					# Use a manual read loop (not body.each) so that body.close runs after the terminal chunk is written. With body.each, the ensure { close } fires before the terminal "0\r\n\r\n" is sent, delaying the client.
					while chunk = body.read
						next if chunk.size == 0
						
						@stream.write("#{chunk.bytesize.to_s(16).upcase}\r\n")
						@stream.write(chunk)
						@stream.write(CRLF)
						
						@stream.flush unless body.ready?
					end
					
					if trailer&.any?
						@stream.write("0\r\n")
						write_headers(trailer)
						@stream.write("\r\n")
					else
						@stream.write("0\r\n\r\n")
					end
					
					@stream.flush
				end
			rescue => error
				raise
			ensure
				# Close the body after the complete chunked response (including terminal chunk) is flushed, so that completion callbacks don't block the client from seeing the response as complete:
				body.close(error)
				
				self.send_end_stream!
			end
			
			# Write the body to the connection and close the connection.
			#
			# @parameter body [Object] the body to write.
			# @parameter head [Boolean] whether the request was a `HEAD` request.
			def write_body_and_close(body, head)
				# We can't be persistent because we don't know the data length:
				@persistent = false
				
				@stream.write("\r\n")
				
				unless head
					@stream.flush unless body.ready?
					
					while chunk = body.read
						@stream.write(chunk)
						
						@stream.flush unless body.ready?
					end
				end
				
				@stream.flush
				@stream.close_write
			rescue => error
				raise
			ensure
				# Close the body after the stream is fully written and half-closed, so that completion callbacks run after the client has received the full response:
				body.close(error)
				
				self.send_end_stream!
			end
			
			# The connection (stream) was closed. It may now be in the idle state.
			#
			# Sub-classes may override this method to perform additional cleanup.
			#
			# @parameter error [Exception | Nil] the error that caused the connection to be closed, if any.
			def closed(error = nil)
			end
			
			# Transition to the closed state.
			#
			# If no error occurred, and the connection is persistent, this will immediately transition to the idle state.
			#
			# @parameter error [Exxception] the error that caused the connection to close.
			def close!(error = nil)
				if @persistent and !error
					# If there was no error, and the connection is persistent, we can reuse it:
					@state = :idle
				else
					@state = :closed
				end
				
				self.closed(error)
			end
			
			# Write a body to the connection.
			#
			# The behavior of this method is determined by the HTTP version, the body, and the request method. We try to choose the best approach possible, given the constraints, connection persistence, whether the length is known, etc.
			#
			# @parameter version [String] the HTTP version.
			# @parameter body [Object] the body to write.
			# @parameter head [Boolean] whether the request was a `HEAD` request.
			# @parameter trailer [Hash | Nil] the trailers to write.
			def write_body(version, body, head = false, trailer = nil)
				# HTTP/1.0 cannot in any case handle trailers.
				if version == HTTP10 # or te: trailers was not present (strictly speaking not required.)
					trailer = nil
				end
				
				# While writing the body, we don't know if trailers will be added. We must choose a different body format depending on whether there is the chance of trailers, even if trailer.any? is currently false.
				#
				# Below you notice `and trailer.nil?`. I tried this but content-length is more important than trailers.
				
				if body.nil?
					write_connection_header(version)
					write_empty_body(body)
				elsif length = body.length # and trailer.nil?
					write_connection_header(version)
					write_fixed_length_body(body, length, head)
				elsif body.empty?
					# Even thought this code is the same as the first clause `body.nil?`, HEAD responses have an empty body but still carry a content length. `write_fixed_length_body` takes care of this appropriately.
					write_connection_header(version)
					write_empty_body(body)
				elsif version == HTTP11
					write_connection_header(version)
					# We specifically ensure that non-persistent connections do not use chunked response, so that hijacking works as expected.
					write_chunked_body(body, head, trailer)
				else
					@persistent = false
					write_connection_header(version)
					write_body_and_close(body, head)
				end
			end
			
			# Indicate that the end of the stream (body) has been received.
			#
			# This will transition to the half-closed remote state if the connection is open, or the closed state if the connection is half-closed local.
			#
			# @raises [ProtocolError] if the connection is not in the open or half-closed remote state.
			def receive_end_stream!
				if @state == :open
					@state = :half_closed_remote
				elsif @state == :half_closed_local
					self.close!
				else
					raise ProtocolError, "Cannot receive end stream in state: #{@state}!"
				end
			end
			
			# Read the body, assuming it is using the chunked transfer encoding.
			#
			# @parameters headers [Hash] the headers of the request.
			# @returns [Protocol::HTTP1::Body::Chunked] the body.
			def read_chunked_body(headers)
				Body::Chunked.new(self, headers)
			end
			
			# Read the body, assuming it has a fixed length.
			#
			# @parameters length [Integer] the length of the body.
			# @returns [Protocol::HTTP1::Body::Fixed] the body.
			def read_fixed_body(length)
				Body::Fixed.new(self, length)
			end
			
			# Read the body, assuming that we read until the connection is closed.
			#
			# @returns [Protocol::HTTP1::Body::Remainder] the body.
			def read_remainder_body
				@persistent = false
				Body::Remainder.new(self)
			end
			
			# Read the body, assuming that we are not receiving any actual data, but just the length.
			#
			# @parameters length [Integer] the length of the body.
			# @returns [Protocol::HTTP::Body::Head] the body.
			def read_head_body(length)
				# We are not receiving any body:
				self.receive_end_stream!
				
				Protocol::HTTP::Body::Head.new(length)
			end
			
			# Read the body, assuming it is a tunnel.
			#
			# Invokes {read_remainder_body}.
			#
			# @returns [Protocol::HTTP::Body::Remainder] the body.
			def read_tunnel_body
				read_remainder_body
			end
			
			# Read the body, assuming it is an upgrade.
			#
			# Invokes {read_remainder_body}.
			#
			# @returns [Protocol::HTTP::Body::Remainder] the body.
			def read_upgrade_body
				# When you have an incoming upgrade request body, we must be extremely careful not to start reading it until the upgrade has been confirmed, otherwise if the upgrade was rejected and we started forwarding the incoming request body, it would desynchronize the connection (potential security issue).
				# We mitigate this issue by setting @persistent to false, which will prevent the connection from being reused, even if the upgrade fails (potential performance issue).
				read_remainder_body
			end
			
			# The HTTP `HEAD` method.
			HEAD = "HEAD"
			
			# The HTTP `CONNECT` method.
			CONNECT = "CONNECT"
			
			# The pattern for valid content length values.
			VALID_CONTENT_LENGTH = /\A\d+\z/
			
			# Extract the content length from the headers, if possible.
			#
			# @parameter headers [Hash] the headers.
			# @yields {|length| ...} if a content length is found.
			# 	@parameter length [Integer] the content length.
			# @raises [BadRequest] if the content length is invalid.
			def extract_content_length(headers)
				if content_length = headers.delete(CONTENT_LENGTH)
					if content_length =~ VALID_CONTENT_LENGTH
						yield Integer(content_length, 10)
					else
						raise BadRequest, "Invalid content length: #{content_length.inspect}"
					end
				end
			end
			
			# Read the body of the response.
			#
			# - The `HEAD` method is used to retrieve the headers of the response without the body, so {read_head_body} is invoked if there is a content length, otherwise nil is returned.
			# - A 101 status code indicates that the connection will be upgraded, so {read_upgrade_body} is invoked.
			# - Interim status codes (1xx), no content (204) and not modified (304) status codes do not have a body, so nil is returned.
			# - The `CONNECT` method is used to establish a tunnel, so {read_tunnel_body} is invoked.
			# - Otherwise, the body is read according to {read_body}.
			#
			# @parameter method [String] the HTTP method.
			# @parameter status [Integer] the HTTP status code.
			# @parameter headers [Hash] the headers of the response.
			def read_response_body(method, status, headers)
				# RFC 7230 3.3.3
				# 1.  Any response to a HEAD request and any response with a 1xx
				# (Informational), 204 (No Content), or 304 (Not Modified) status
				# code is always terminated by the first empty line after the
				# header fields, regardless of the header fields present in the
				# message, and thus cannot contain a message body.
				if method == HTTP::Methods::HEAD
					extract_content_length(headers) do |length|
						if length > 0
							return read_head_body(length)
						else
							return nil
						end
					end
					
					# There is no body for a HEAD request if there is no content length:
					return nil
				end
				
				if status == 101
					return read_upgrade_body
				end
				
				if (status >= 100 and status < 200) or status == 204 or status == 304
					return nil
				end
				
				# 2.  Any 2xx (Successful) response to a CONNECT request implies that
				# the connection will become a tunnel immediately after the empty
				# line that concludes the header fields.  A client MUST ignore any
				# Content-Length or Transfer-Encoding header fields received in
				# such a message.
				if method == HTTP::Methods::CONNECT and status == 200
					return read_tunnel_body
				end
				
				return read_body(headers, true)
			end
			
			# Read the body of the request.
			#
			# - The `CONNECT` method is used to establish a tunnel, so the body is read until the connection is closed.
			# - The `UPGRADE` method is used to upgrade the connection to a different protocol (typically WebSockets), so the body is read until the connection is closed.
			# - Otherwise, the body is read according to {read_body}.
			#
			# @parameter method [String] the HTTP method.
			# @parameter headers [Hash] the headers of the request.
			def read_request_body(method, headers)
				# 2.  Any 2xx (Successful) response to a CONNECT request implies that
				# the connection will become a tunnel immediately after the empty
				# line that concludes the header fields.  A client MUST ignore any
				# Content-Length or Transfer-Encoding header fields received in
				# such a message.
				if method == HTTP::Methods::CONNECT
					return read_tunnel_body
				end
				
				# A successful upgrade response implies that the connection will become a tunnel immediately after the empty line that concludes the header fields.
				if headers[UPGRADE]
					return read_upgrade_body
				end
				
				# 6.  If this is a request message and none of the above are true, then
				# the message body length is zero (no message body is present).
				return read_body(headers)
			end
			
			# Read the body of the message.
			#
			# - The `transfer-encoding` header is used to determine if the body is chunked.
			# - Otherwise, if the `content-length` is present, the body is read until the content length is reached.
			# - Otherwise, if `remainder` is true, the body is read until the connection is closed.
			#
			# @parameter headers [Hash] the headers of the message.
			# @parameter remainder [Boolean] whether to read the remainder of the body.
			# @returns [Object] the body.
			def read_body(headers, remainder = false)
				# 3.  If a Transfer-Encoding header field is present and the chunked
				# transfer coding (Section 4.1) is the final encoding, the message
				# body length is determined by reading and decoding the chunked
				# data until the transfer coding indicates the data is complete.
				if transfer_encoding = headers.delete(TRANSFER_ENCODING)
					# If a message is received with both a Transfer-Encoding and a
					# Content-Length header field, the Transfer-Encoding overrides the
					# Content-Length.  Such a message might indicate an attempt to
					# perform request smuggling (Section 9.5) or response splitting
					# (Section 9.4) and ought to be handled as an error.  A sender MUST
					# remove the received Content-Length field prior to forwarding such
					# a message downstream.
					if headers[CONTENT_LENGTH]
						raise BadRequest, "Message contains both transfer encoding and content length!"
					end
					
					if transfer_encoding.last == CHUNKED
						return read_chunked_body(headers)
					else
						# If a Transfer-Encoding header field is present in a response and
						# the chunked transfer coding is not the final encoding, the
						# message body length is determined by reading the connection until
						# it is closed by the server.  If a Transfer-Encoding header field
						# is present in a request and the chunked transfer coding is not
						# the final encoding, the message body length cannot be determined
						# reliably; the server MUST respond with the 400 (Bad Request)
						# status code and then close the connection.
						return read_remainder_body
					end
				end
				
				# 5.  If a valid Content-Length header field is present without
				# Transfer-Encoding, its decimal value defines the expected message
				# body length in octets.  If the sender closes the connection or
				# the recipient times out before the indicated number of octets are
				# received, the recipient MUST consider the message to be
				# incomplete and close the connection.
				extract_content_length(headers) do |length|
					if length > 0
						return read_fixed_body(length)
					else
						return nil
					end
				end
				
				# http://tools.ietf.org/html/rfc2068#section-19.7.1.1
				if remainder
					# 7.  Otherwise, this is a response message without a declared message
					# body length, so the message body length is determined by the
					# number of octets received prior to the server closing the
					# connection.
					return read_remainder_body
				end
			end
		end
	end
end
