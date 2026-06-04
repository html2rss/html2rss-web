# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "connection"

module Protocol
	module HTTP2
		# A single HTTP/2 connection can multiplex multiple streams in parallel:
		# multiple requests and responses can be in flight simultaneously and stream
		# data can be interleaved and prioritized.
		#
		# This class encapsulates all of the state, transition, flow-control, and
		# error management as defined by the HTTP 2.0 specification. All you have
		# to do is subscribe to appropriate events (marked with ":" prefix in
		# diagram below) and provide your application logic to handle request
		# and response processing.
		#
		# ```
		#                          ┌────────┐
		#                  send PP │        │ recv PP
		#               ┌──────────┤  idle  ├──────────┐
		#               │          │        │          │
		#               ▼          └───┬────┘          ▼
		#        ┌──────────┐          │           ┌──────────┐
		#        │          │          │ send H /  │          │
		# ┌──────┼ reserved │          │ recv H    │ reserved ├──────┐
		# │      │ (local)  │          │           │ (remote) │      │
		# │      └───┬──────┘          ▼           └──────┬───┘      │
		# │          │             ┌────────┐             │          │
		# │          │     recv ES │        │ send ES     │          │
		# │   send H │   ┌─────────┤  open  ├─────────┐   │ recv H   │
		# │          │   │         │        │         │   │          │
		# │          ▼   ▼         └───┬────┘         ▼   ▼          │
		# │      ┌──────────┐          │           ┌──────────┐      │
		# │      │   half   │          │           │   half   │      │
		# │      │  closed  │          │ send R /  │  closed  │      │
		# │      │ (remote) │          │ recv R    │ (local)  │      │
		# │      └────┬─────┘          │           └─────┬────┘      │
		# │           │                │                 │           │
		# │           │ send ES /      │       recv ES / │           │
		# │           │ send R /       ▼        send R / │           │
		# │           │ recv R     ┌────────┐   recv R   │           │
		# │ send R /  └───────────►│        │◄───────────┘  send R / │
		# │ recv R                 │ closed │               recv R   │
		# └───────────────────────►│        │◄───────────────────────┘
		#                          └────────┘
		# ```
		#
		# - `send`: endpoint sends this frame
		# - `recv`: endpoint receives this frame
		#
		# - H:  HEADERS frame (with implied CONTINUATIONs)
		# - PP: PUSH_PROMISE frame (with implied CONTINUATIONs)
		# - ES: END_STREAM flag
		# - R:  RST_STREAM frame
		#
		# State transition methods use a trailing "!".
		class Stream
			include FlowControlled
			
			# Create a new stream and add it to the connection.
			# @parameter connection [Connection] The connection this stream belongs to.
			# @parameter id [Integer] The stream identifier.
			# @returns [Stream] The newly created stream.
			def self.create(connection, id)
				stream = self.new(connection, id)
				
				connection.streams[id] = stream
				
				return stream
			end
			
			# Initialize a new stream.
			# @parameter connection [Connection] The connection this stream belongs to.
			# @parameter id [Integer] The stream identifier.
			# @parameter state [Symbol] The initial stream state.
			def initialize(connection, id, state = :idle)
				@connection = connection
				@id = id
				
				@state = state
				
				@local_window = Window.new(@connection.local_settings.initial_window_size)
				@remote_window = Window.new(@connection.remote_settings.initial_window_size)
				
				@priority = nil
			end
			
			# The connection this stream belongs to.
			attr :connection
			
			# Stream ID (odd for client initiated streams, even otherwise).
			attr :id
			
			# Stream state, e.g. `idle`, `closed`.
			attr_accessor :state
			
			attr :local_window
			attr :remote_window
			
			# @attribute [Protocol::HTTP::Header::Priority | Nil] the priority of the stream.
			attr_accessor :priority
			
			# Get the maximum frame size for this stream.
			# @returns [Integer] The maximum frame size from connection settings.
			def maximum_frame_size
				@connection.available_frame_size
			end
			
			# Write a frame to the connection for this stream.
			# @parameter frame [Frame] The frame to write.
			def write_frame(frame)
				@connection.write_frame(frame)
			end
			
			# Check if the stream is active (not idle or closed).
			# @returns [Boolean] True if the stream is active.
			def active?
				@state != :closed && @state != :idle
			end
			
			# Check if the stream is closed.
			# @returns [Boolean] True if the stream is in closed state.
			def closed?
				@state == :closed
			end
			
			# Transition directly to closed state. Do not pass go, do not collect $200.
			# This method should only be used by `Connection#close`.
			def close(error = nil)
				unless closed?
					@state = :closed
					self.closed(error)
				end
			end
			
			# HEADERS frames can be sent on a stream in the "idle", "reserved (local)", "open", or "half-closed (remote)" state. Despite it's name, it can also be used for trailers.
			def send_headers?
				@state == :idle or @state == :reserved_local or @state == :open or @state == :half_closed_remote
			end
			
			private def write_headers(headers, flags = 0)
				frame = HeadersFrame.new(@id, flags)
				
				@connection.write_frames do |framer|
					data = @connection.encode_headers(headers)
					
					frame.pack(data, maximum_size: @connection.maximum_frame_size)
					
					framer.write_frame(frame)
				end
				
				return frame
			end
			
			# The HEADERS frame is used to open a stream, and additionally carries a header block fragment. HEADERS frames can be sent on a stream in the "idle", "reserved (local)", "open", or "half-closed (remote)" state.
			def send_headers(*arguments)
				if @state == :idle
					frame = write_headers(*arguments)
					
					if frame.end_stream?
						@state = :half_closed_local
					else
						open!
					end
				elsif @state == :reserved_local
					frame = write_headers(*arguments)
					
					@state = :half_closed_remote
				elsif @state == :open
					frame = write_headers(*arguments)
					
					if frame.end_stream?
						@state = :half_closed_local
					end
				elsif @state == :half_closed_remote
					frame = write_headers(*arguments)
					
					if frame.end_stream?
						close!
					end
				else
					raise ProtocolError, "Cannot send headers in state: #{@state}"
				end
			end
			
			# Consume from the remote window for both stream and connection.
			# @parameter frame [Frame] The frame that consumes window space.
			def consume_remote_window(frame)
				super
				
				@connection.consume_remote_window(frame)
			end
			
			private def write_data(data, flags = 0, **options)
				frame = DataFrame.new(@id, flags)
				frame.pack(data, **options)
				
				# This might fail if the data payload was too big:
				consume_remote_window(frame)
				write_frame(frame)
				
				return frame
			end
			
			# Send data over this stream.
			# @parameter arguments [Array] Arguments passed to write_data.
			# @parameter options [Hash] Options passed to write_data.
			def send_data(*arguments, **options)
				if @state == :open
					frame = write_data(*arguments, **options)
					
					if frame.end_stream?
						@state = :half_closed_local
					end
				elsif @state == :half_closed_remote
					frame = write_data(*arguments, **options)
					
					if frame.end_stream?
						close!
					end
				else
					raise ProtocolError, "Cannot send data in state: #{@state}"
				end
			end
			
			# Open the stream by transitioning from idle to open state.
			# @returns [Stream] Returns self for chaining.
			# @raises [ProtocolError] If the stream cannot be opened from current state.
			def open!
				if @state == :idle
					@state = :open
				else
					raise ProtocolError, "Cannot open stream in state: #{@state}"
				end
				
				return self
			end
			
			# The stream has been closed. If closed due to a stream reset, the error will be set.
			def closed(error = nil)
			end
			
			# Transition the stream into the closed state.
			# @parameter error_code [Integer] the error code if the stream was closed due to a stream reset.
			def close!(error_code = nil)
				@state = :closed
				@connection.delete(@id)
				
				if error_code
					if error_code == REFUSED_STREAM
						error = ::Protocol::HTTP::RefusedError.new("Stream refused.")
					else
						error = StreamError.new("Stream closed!", error_code)
					end
				end
				
				self.closed(error)
				
				return self
			end
			
			# Send a RST_STREAM frame to reset this stream.
			# @parameter error_code [Integer] The error code to send.
			def send_reset_stream(error_code = 0)
				if @state != :idle and @state != :closed
					frame = ResetStreamFrame.new(@id)
					frame.pack(error_code)
					
					write_frame(frame)
					
					close!
				else
					raise ProtocolError, "Cannot send reset stream (#{error_code}) in state: #{@state}"
				end
			end
			
			# Process headers frame and decode the header block.
			# @parameter frame [HeadersFrame] The headers frame to process.
			# @returns [Array] The decoded headers.
			def process_headers(frame)
				# Receiving request headers:
				data = frame.unpack
				
				@connection.decode_headers(data)
			end
			
			protected def ignore_headers(frame)
				# Console.warn(self) {"Received headers in state: #{@state}!"}
			end
			
			# Receive and process a headers frame on this stream.
			# @parameter frame [HeadersFrame] The headers frame to receive.
			def receive_headers(frame)
				if @state == :idle
					if frame.end_stream?
						@state = :half_closed_remote
					else
						open!
					end
					
					process_headers(frame)
				elsif @state == :reserved_remote
					process_headers(frame)
					
					@state = :half_closed_local
				elsif @state == :open
					process_headers(frame)
					
					if frame.end_stream?
						@state = :half_closed_remote
					end
				elsif @state == :half_closed_local
					process_headers(frame)
					
					if frame.end_stream?
						close!
					end
				elsif self.closed?
					ignore_headers(frame)
				else
					self.send_reset_stream(Error::STREAM_CLOSED)
				end
			end
			
			# @return [String] the data that was received.
			def process_data(frame)
				frame.unpack
			end
			
			# Ignore data frame when in an invalid state.
			# @parameter frame [DataFrame] The data frame to ignore.
			def ignore_data(frame)
				# Console.warn(self) {"Received headers in state: #{@state}!"}
			end
			
			# DATA frames are subject to flow control and can only be sent when a stream is in the "open" or "half-closed (remote)" state.  The entire DATA frame payload is included in flow control, including the Pad Length and Padding fields if present.  If a DATA frame is received whose stream is not in "open" or "half-closed (local)" state, the recipient MUST respond with a stream error of type STREAM_CLOSED.
			def receive_data(frame)
				if @state == :open
					update_local_window(frame)
					
					if frame.end_stream?
						@state = :half_closed_remote
					end
					
					process_data(frame)
				elsif @state == :half_closed_local
					update_local_window(frame)
					
					process_data(frame)
					
					if frame.end_stream?
						close!
					end
				elsif self.closed?
					ignore_data(frame)
				else
					# If a DATA frame is received whose stream is not in "open" or "half-closed (local)" state, the recipient MUST respond with a stream error (Section 5.4.2) of type STREAM_CLOSED.
					self.send_reset_stream(Error::STREAM_CLOSED)
				end
			end
			
			# Receive and process a RST_STREAM frame on this stream.
			# @parameter frame [ResetStreamFrame] The reset stream frame to receive.
			# @returns [Integer] The error code from the reset frame.
			# @raises [ProtocolError] If reset is received on an idle stream.
			def receive_reset_stream(frame)
				if @state == :idle
					# If a RST_STREAM frame identifying an idle stream is received, the recipient MUST treat this as a connection error (Section 5.4.1) of type PROTOCOL_ERROR.
					raise ProtocolError, "Cannot receive reset stream in state: #{@state}!"
				else
					error_code = frame.unpack
					
					close!(error_code)
					
					return error_code
				end
			end
			
			# A normal request is client request -> server response -> client.
			# A push promise is server request -> client -> server response -> client.
			# The server generates the same set of headers as if the client was sending a request, and sends these to the client. The client can reject the request by resetting the (new) stream. Otherwise, the server will start sending a response as if the client had send the request.
			private def write_push_promise(stream_id, headers, flags = 0, **options)
				frame = PushPromiseFrame.new(@id, flags)
				
				@connection.write_frames do |framer|
					data = @connection.encode_headers(headers)
					
					frame.pack(stream_id, data, maximum_size: @connection.maximum_frame_size)
					
					framer.write_frame(frame)
				end
				
				return frame
			end
			
			# Transition stream to reserved local state.
			# @returns [Stream] Returns self for chaining.
			# @raises [ProtocolError] If the stream cannot be reserved from current state.
			def reserved_local!
				if @state == :idle
					@state = :reserved_local
				else
					raise ProtocolError, "Cannot reserve stream in state: #{@state}"
				end
				
				return self
			end
			
			# Transition stream to reserved remote state.
			# @returns [Stream] Returns self for chaining.
			# @raises [ProtocolError] If the stream cannot be reserved from current state.
			def reserved_remote!
				if @state == :idle
					@state = :reserved_remote
				else
					raise ProtocolError, "Cannot reserve stream in state: #{@state}"
				end
				
				return self
			end
			
			# Override this function to implement your own push promise logic.
			def create_push_promise_stream(headers)
				@connection.create_push_promise_stream
			end
			
			# Server push is semantically equivalent to a server responding to a request; however, in this case, that request is also sent by the server, as a PUSH_PROMISE frame.
			# @parameter headers [Hash] contains a complete set of request header fields that the server attributes to the request.
			def send_push_promise(headers)
				if @state == :open or @state == :half_closed_remote
					promised_stream = self.create_push_promise_stream(headers)
					promised_stream.reserved_local!
					
					# The headers are the same as if the client had sent a request:
					write_push_promise(promised_stream.id, headers)
					
					# The server should call send_headers on the promised stream to begin sending the response:
					return promised_stream
				else
					raise ProtocolError, "Cannot send push promise in state: #{@state}"
				end
			end
			
			# Override this function to implement your own push promise logic.
			def accept_push_promise_stream(stream_id, headers)
				@connection.accept_push_promise_stream(stream_id)
			end
			
			# Receive and process a PUSH_PROMISE frame on this stream.
			# @parameter frame [PushPromiseFrame] The push promise frame to receive.
			def receive_push_promise(frame)
				promised_stream_id, data = frame.unpack
				headers = @connection.decode_headers(data)
				
				stream = self.accept_push_promise_stream(promised_stream_id, headers)
				stream.reserved_remote!
				
				return stream, headers
			end
			
			# Get a string representation of the stream.
			# @returns [String] Human-readable stream information.
			def inspect
				"\#<#{self.class} id=#{@id} state=#{@state}>"
			end
		end
	end
end
