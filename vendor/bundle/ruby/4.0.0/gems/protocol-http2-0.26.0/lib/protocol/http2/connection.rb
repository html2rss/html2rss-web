# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2023, by Marco Concetto Rudilosso.

require_relative "framer"
require_relative "flow_controlled"

require "protocol/hpack"
require "protocol/http/header/priority"

module Protocol
	module HTTP2
		# This is the core connection class that handles HTTP/2 protocol semantics including
		# stream management, settings negotiation, and frame processing.
		class Connection
			include FlowControlled
			
			# Initialize a new HTTP/2 connection.
			# @parameter framer [Framer] The frame handler for reading/writing HTTP/2 frames.
			# @parameter local_stream_id [Integer] The starting stream ID for locally-initiated streams.
			def initialize(framer, local_stream_id)
				super()
				
				@state = :new
				
				# Hash(Integer, Stream)
				@streams = {}
				
				@framer = framer
				
				# The next stream id to use:
				@local_stream_id = local_stream_id
				
				# The biggest remote stream id seen thus far:
				@remote_stream_id = 0
				
				@local_settings = PendingSettings.new
				@remote_settings = Settings.new
				
				@decoder = HPACK::Context.new
				@encoder = HPACK::Context.new
				
				@local_window = LocalWindow.new
				@remote_window = Window.new
			end
			
			# The connection stream ID (always 0 for connection-level operations).
			# @returns [Integer] Always returns 0 for the connection itself.
			def id
				0
			end
			
			# Access streams by ID, with 0 returning the connection itself.
			# @parameter id [Integer] The stream ID to look up.
			# @returns [Connection | Stream | Nil] The connection (if id=0), stream, or nil.
			def [] id
				if id.zero?
					self
				else
					@streams[id]
				end
			end
			
			# The size of a frame payload is limited by the maximum size that a receiver advertises in the SETTINGS_MAX_FRAME_SIZE setting.
			def maximum_frame_size
				@remote_settings.maximum_frame_size
			end
			
			# The maximum number of concurrent streams that this connection can initiate. This is a setting that can be changed by the remote peer.
			#
			# It is not the same as the number of streams that can be accepted by the connection. The number of streams that can be accepted is determined by the local settings, and the number of streams that can be initiated is determined by the remote settings.
			def maximum_concurrent_streams
				@remote_settings.maximum_concurrent_streams
			end
			
			attr :framer
			
			# Connection state (:new, :open, :closed).
			attr_accessor :state
			
			# Current settings value for local and peer
			attr_accessor :local_settings
			attr_accessor :remote_settings
			
			# Our window for receiving data. When we receive data, it reduces this window.
			# If the window gets too small, we must send a window update.
			attr :local_window
			
			# Our window for sending data. When we send data, it reduces this window.
			attr :remote_window
			
			# The highest stream_id that has been successfully accepted by this connection.
			attr :remote_stream_id
			
			# Whether the connection is effectively or actually closed.
			def closed?
				@state == :closed || @framer.nil?
			end
			
			# Remove a stream from the active streams collection.
			# @parameter id [Integer] The stream ID to remove.
			# @returns [Stream | Nil] The removed stream, or nil if not found.
			def delete(id)
				@streams.delete(id)
			end
			
			# Close the underlying framer and all streams.
			def close(error = nil)
				# The underlying socket may already be closed by this point.
				
				# If there are active streams when the connection closes, it's an error for those streams, even if the connection itself closed cleanly:
				if @streams.any? and error.nil?
					error = EOFError.new("Connection closed with #{@streams.size} active stream(s)!")
				end
				
				@streams.each_value{|stream| stream.close(error)}
				@streams.clear
				
			ensure
				if @framer
					@framer.close
					@framer = nil
				end
			end
			
			# Encode headers using HPACK compression.
			# @parameter headers [Array] The headers to encode.
			# @parameter buffer [String] Optional buffer for encoding output.
			# @returns [String] The encoded header block.
			def encode_headers(headers, buffer = String.new.b)
				HPACK::Compressor.new(buffer, @encoder, table_size_limit: @remote_settings.header_table_size).encode(headers)
			end
			
			# Decode headers using HPACK decompression.
			# @parameter data [String] The encoded header block data.
			# @returns [Array] The decoded headers.
			def decode_headers(data)
				HPACK::Decompressor.new(data, @decoder, table_size_limit: @local_settings.header_table_size).decode
			end
			
			# Streams are identified with an unsigned 31-bit integer.  Streams initiated by a client MUST use odd-numbered stream identifiers; those initiated by the server MUST use even-numbered stream identifiers.  A stream identifier of zero (0x0) is used for connection control messages; the stream identifier of zero cannot be used to establish a new stream.
			def next_stream_id
				id = @local_stream_id
				
				@local_stream_id += 2
				
				return id
			end
			
			attr :streams
			
			attr :dependencies
			
			attr :dependency
			
			# 6.8. GOAWAY
			# There is an inherent race condition between an endpoint starting new streams and the remote sending a GOAWAY frame. To deal with this case, the GOAWAY contains the stream identifier of the last peer-initiated stream that was or might be processed on the sending endpoint in this connection. For instance, if the server sends a GOAWAY frame, the identified stream is the highest-numbered stream initiated by the client.
			# Once sent, the sender will ignore frames sent on streams initiated by the receiver if the stream has an identifier higher than the included last stream identifier. Receivers of a GOAWAY frame MUST NOT open additional streams on the connection, although a new connection can be established for new streams.
			def ignore_frame?(frame)
				if self.closed?
					# puts "ignore_frame? #{frame.stream_id} -> #{valid_remote_stream_id?(frame.stream_id)} > #{@remote_stream_id}"
					if valid_remote_stream_id?(frame.stream_id)
						return frame.stream_id > @remote_stream_id
					end
				end
			end
			
			# Execute a block within a synchronized context.
			# This method provides a synchronization primitive for thread safety.
			# @yields The block to execute within the synchronized context.
			def synchronize
				yield
			end
			
			# Reads one frame from the network and processes. Processing the frame updates the state of the connection and related streams. If the frame triggers an error, e.g. a protocol error, the connection will typically emit a goaway frame and re-raise the exception. You should continue processing frames until the underlying connection is closed.
			def read_frame
				frame = @framer.read_frame(@local_settings.maximum_frame_size)
				
				# puts "#{self.class} #{@state} read_frame: class=#{frame.class} stream_id=#{frame.stream_id} flags=#{frame.flags} length=#{frame.length} (remote_stream_id=#{@remote_stream_id})"
				# puts "Windows: local_window=#{@local_window.inspect}; remote_window=#{@remote_window.inspect}"
				
				return if ignore_frame?(frame)
				
				yield frame if block_given?
				frame.apply(self)
				
				return frame
			rescue GoawayError => error
				# Go directly to jail. Do not pass go, do not collect $200.
				raise
			rescue ProtocolError => error
				send_goaway(error.code || PROTOCOL_ERROR, error.message)
				
				raise
			rescue HPACK::Error => error
				send_goaway(COMPRESSION_ERROR, error.message)
				
				raise
			end
			
			# Send updated settings to the remote peer.
			# @parameter changes [Hash] The settings changes to send.
			def send_settings(changes)
				@local_settings.append(changes)
				
				frame = SettingsFrame.new
				frame.pack(changes)
				
				write_frame(frame)
			end
			
			# Transition the connection into the closed state.
			def close!
				@state = :closed
				
				return self
			end
			
			# Tell the remote end that the connection is being shut down. If the `error_code` is 0, this is a graceful shutdown. The other end of the connection should not make any new streams, but existing streams may be completed.
			def send_goaway(error_code = 0, message = "")
				frame = GoawayFrame.new
				frame.pack @remote_stream_id, error_code, message
				
				write_frame(frame)
			ensure
				self.close!
			end
			
			# Process a GOAWAY frame from the remote peer.
			# @parameter frame [GoawayFrame] The GOAWAY frame to process.
			# @raises [GoawayError] If the frame indicates a connection error.
			def receive_goaway(frame)
				# We capture the last stream that was processed.
				@remote_stream_id, error_code, message = frame.unpack
				
				self.close!
				
				# Streams above the last stream ID were not processed by the remote peer and are safe to retry (RFC 9113 §6.8).
				error = ::Protocol::HTTP::RefusedError.new("GOAWAY: request not processed.")
				
				@streams.each_value do |stream|
					if stream.id > @remote_stream_id
						stream.close(error)
					end
				end
				
				if error_code != 0
					# Shut down immediately.
					raise GoawayError.new(message, error_code)
				end
			end
			
			# Write a single frame to the connection.
			# @parameter frame [Frame] The frame to write.
			def write_frame(frame)
				synchronize do
					@framer.write_frame(frame)
				end
				
				@framer.flush
			end
			
			# Write multiple frames within a synchronized block.
			# @yields {|framer| ...} The framer for writing multiple frames.
			#   @parameter framer [Framer] The framer instance.
			# @raises [EOFError] If the connection is closed.
			def write_frames
				if @framer
					synchronize do
						yield @framer
					end
					
					@framer.flush
				else
					raise EOFError, "Connection closed!"
				end
			end
			
			# Update local settings and adjust stream window capacities.
			# @parameter changes [Hash] The settings changes to apply locally.
			def update_local_settings(changes)
				capacity = @local_settings.initial_window_size
				
				@streams.each_value do |stream|
					stream.local_window.capacity = capacity
				end
				
				@local_window.desired = capacity
			end
			
			# Update remote settings and adjust stream window capacities.
			# @parameter changes [Hash] The settings changes to apply to remote peer.
			def update_remote_settings(changes)
				capacity = @remote_settings.initial_window_size
				
				@streams.each_value do |stream|
					stream.remote_window.capacity = capacity
				end
			end
			
			# In addition to changing the flow-control window for streams that are not yet active, a SETTINGS frame can alter the initial flow-control window size for streams with active flow-control windows (that is, streams in the "open" or "half-closed (remote)" state).  When the value of SETTINGS_INITIAL_WINDOW_SIZE changes, a receiver MUST adjust the size of all stream flow-control windows that it maintains by the difference between the new value and the old value.
			#
			# @return [Boolean] whether the frame was an acknowledgement
			def process_settings(frame)
				if frame.acknowledgement?
					# The remote end has confirmed the settings have been received:
					changes = @local_settings.acknowledge
					
					update_local_settings(changes)
					
					return true
				else
					# The remote end is updating the settings, we reply with acknowledgement:
					reply = frame.acknowledge
					
					write_frame(reply)
					
					changes = frame.unpack
					@remote_settings.update(changes)
					
					update_remote_settings(changes)
					
					return false
				end
			end
			
			# Transition the connection to the open state.
			# @returns [Connection] Self for method chaining.
			def open!
				@state = :open
				
				return self
			end
			
			# Receive and process a SETTINGS frame from the remote peer.
			# @parameter frame [SettingsFrame] The settings frame to process.
			# @raises [ProtocolError] If the connection is in an invalid state.
			def receive_settings(frame)
				if @state == :new
					# We transition to :open when we receive acknowledgement of first settings frame:
					open! if process_settings(frame)
				elsif @state != :closed
					process_settings(frame)
				else
					raise ProtocolError, "Cannot receive settings in state #{@state}"
				end
			end
			
			# Send a PING frame to the remote peer.
			# @parameter data [String] The 8-byte ping payload data.
			def send_ping(data)
				if @state != :closed
					frame = PingFrame.new
					frame.pack data
					
					write_frame(frame)
				else
					raise ProtocolError, "Cannot send ping in state #{@state}"
				end
			end
			
			# Process a PING frame from the remote peer.
			# @parameter frame [PingFrame] The ping frame to process.
			# @raises [ProtocolError] If ping is received in invalid state.
			def receive_ping(frame)
				if @state != :closed
					# This is handled in `read_payload`:
					# if frame.stream_id != 0
					# 	raise ProtocolError, "Ping received for non-zero stream!"
					# end
					
					unless frame.acknowledgement?
						reply = frame.acknowledge
						
						write_frame(reply)
					end
				else
					raise ProtocolError, "Cannot receive ping in state #{@state}"
				end
			end
			
			# Process a DATA frame from the remote peer.
			# @parameter frame [DataFrame] The data frame to process.
			# @raises [ProtocolError] If data is received for invalid stream.
			def receive_data(frame)
				update_local_window(frame)
				
				if stream = @streams[frame.stream_id]
					stream.receive_data(frame)
				elsif closed_stream_id?(frame.stream_id)
					# This can occur if one end sent a stream reset, while the other end was sending a data frame. It's mostly harmless.
				else
					raise ProtocolError, "Cannot receive data for stream id #{frame.stream_id}"
				end
			end
			
			# Check if the given stream ID is valid for remote initiation.
			# This method should be overridden by client/server implementations.
			# @parameter stream_id [Integer] The stream ID to validate.
			# @returns [Boolean] True if the stream ID is valid for remote initiation.
			def valid_remote_stream_id?(stream_id)
				false
			end
			
			# Accept an incoming stream from the other side of the connnection.
			# On the server side, we accept requests.
			def accept_stream(stream_id, &block)
				unless valid_remote_stream_id?(stream_id)
					raise ProtocolError, "Invalid stream id: #{stream_id}"
				end
				
				create_stream(stream_id, &block)
			end
			
			# Accept an incoming push promise from the other side of the connection.
			# On the client side, we accept push promise streams.
			# On the server side, existing streams create push promise streams.
			def accept_push_promise_stream(stream_id, &block)
				accept_stream(stream_id, &block)
			end
			
			# Create a stream, defaults to an outgoing stream.
			# On the client side, we create requests.
			# @return [Stream] the created stream.
			def create_stream(id = next_stream_id, &block)
				if @streams.key?(id)
					raise ProtocolError, "Cannot create stream with id #{id}, already exists!"
				end
				
				if block_given?
					return yield(self, id)
				else
					return Stream.create(self, id)
				end
			end
			
			# Create a push promise stream.
			# This method should be overridden by client/server implementations.
			# @yields {|stream| ...} Optional block to configure the created stream.
			# @returns [Stream] The created push promise stream.
			def create_push_promise_stream(&block)
				create_stream(&block)
			end
			
			# On the server side, starts a new request.
			def receive_headers(frame)
				stream_id = frame.stream_id
				
				if stream_id.zero?
					raise ProtocolError, "Cannot receive headers for stream 0!"
				end
				
				if stream = @streams[stream_id]
					stream.receive_headers(frame)
				else
					if stream_id <= @remote_stream_id
						raise ProtocolError, "Invalid stream id: #{stream_id} <= #{@remote_stream_id}!"
					end
					
					# We need to validate that we have less streams than the specified maximum:
					if @streams.size < @local_settings.maximum_concurrent_streams
						stream = accept_stream(stream_id)
						@remote_stream_id = stream_id
						
						stream.receive_headers(frame)
					else
						raise ProtocolError, "Exceeded maximum concurrent streams"
					end
				end
			end
			
			# Receive and process a PUSH_PROMISE frame.
			# @parameter frame [PushPromiseFrame] The push promise frame.
			# @raises [ProtocolError] Always raises as push promises are not supported.
			def receive_push_promise(frame)
				raise ProtocolError, "Unable to receive push promise!"
			end
			
			# Receive and process a PRIORITY_UPDATE frame.
			# @parameter frame [PriorityUpdateFrame] The priority update frame.
			# @raises [ProtocolError] If the stream ID is invalid.
			def receive_priority_update(frame)
				if frame.stream_id != 0
					raise ProtocolError, "Invalid stream id: #{frame.stream_id}"
				end
				
				stream_id, value = frame.unpack
				
				# Apparently you can set the priority of idle streams, but I'm not sure why that makes sense, so for now let's ignore it.
				if stream = @streams[stream_id]
					stream.priority = Protocol::HTTP::Header::Priority.new(value)
				end
			end
			
			# Check if the given stream ID represents a client-initiated stream.
			# Client streams always have odd numbered IDs.
			# @parameter id [Integer] The stream ID to check.
			# @returns [Boolean] True if the stream ID is client-initiated.
			def client_stream_id?(id)
				id.odd?
			end
			
			# Check if the given stream ID represents a server-initiated stream.
			# Server streams always have even numbered IDs.
			# @parameter id [Integer] The stream ID to check.
			# @returns [Boolean] True if the stream ID is server-initiated.
			def server_stream_id?(id)
				id.even?
			end
			
			# Check if the given stream ID represents an idle stream.
			# @parameter id [Integer] The stream ID to check.
			# @returns [Boolean] True if the stream ID is idle (not yet used).
			def idle_stream_id?(id)
				if id.even?
					# Server-initiated streams are even.
					if @local_stream_id.even?
						id >= @local_stream_id
					else
						id > @remote_stream_id
					end
				elsif id.odd?
					# Client-initiated streams are odd.
					if @local_stream_id.odd?
						id >= @local_stream_id
					else
						id > @remote_stream_id
					end
				end
			end
			
			# This is only valid if the stream doesn't exist in `@streams`.
			def closed_stream_id?(id)
				if id.zero?
					# The connection "stream id" can never be closed:
					false
				else
					!idle_stream_id?(id)
				end
			end
			
			# Receive and process a RST_STREAM frame.
			# @parameter frame [ResetStreamFrame] The reset stream frame.
			# @raises [ProtocolError] If the frame is invalid for connection context.
			def receive_reset_stream(frame)
				if frame.connection?
					raise ProtocolError, "Cannot reset connection!"
				elsif stream = @streams[frame.stream_id]
					stream.receive_reset_stream(frame)
				elsif closed_stream_id?(frame.stream_id)
					# Ignore.
				else
					raise StreamClosed, "Cannot reset stream #{frame.stream_id}"
				end
			end
			
			# Traverse active streams and allow them to consume the available flow-control window.
			# @parameter amount [Integer] the amount of data to write. Defaults to the current window capacity.
			def consume_window(size = self.available_size)
				# Return if there is no window to consume:
				return unless size > 0
				
				@streams.each_value do |stream|
					if stream.active?
						stream.window_updated(size)
					end
				end
			end
			
			# Receive and process a WINDOW_UPDATE frame.
			# @parameter frame [WindowUpdateFrame] The window update frame.
			def receive_window_update(frame)
				if frame.connection?
					super
					
					self.consume_window
				elsif stream = @streams[frame.stream_id]
					begin
						stream.receive_window_update(frame)
					rescue ProtocolError => error
						stream.send_reset_stream(error.code)
					end
				elsif closed_stream_id?(frame.stream_id)
					# Ignore.
				else
					# Receiving any frame other than HEADERS or PRIORITY on a stream in this state (idle) MUST be treated as a connection error of type PROTOCOL_ERROR.
					raise ProtocolError, "Cannot update window of idle stream #{frame.stream_id}"
				end
			end
			
			# Receive and process a CONTINUATION frame.
			# @parameter frame [ContinuationFrame] The continuation frame.
			# @raises [ProtocolError] Always raises as unexpected continuation frames are not supported.
			def receive_continuation(frame)
				raise ProtocolError, "Received unexpected continuation: #{frame.class}"
			end
			
			# Receive and process a generic frame (default handler).
			# @parameter frame [Frame] The frame to receive.
			def receive_frame(frame)
				# ignore.
			end
		end
	end
end
