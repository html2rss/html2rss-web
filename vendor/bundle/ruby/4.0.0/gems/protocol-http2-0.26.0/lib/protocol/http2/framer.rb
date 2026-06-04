# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "error"

require_relative "data_frame"
require_relative "headers_frame"
require_relative "reset_stream_frame"
require_relative "settings_frame"
require_relative "push_promise_frame"
require_relative "ping_frame"
require_relative "goaway_frame"
require_relative "window_update_frame"
require_relative "continuation_frame"
require_relative "priority_update_frame"

module Protocol
	module HTTP2
		# HTTP/2 frame type mapping as defined by the spec
		FRAMES = [
			DataFrame,
			HeadersFrame,
			nil, # PriorityFrame is deprecated and ignored, instead consider using PriorityUpdateFrame instead.
			ResetStreamFrame,
			SettingsFrame,
			PushPromiseFrame,
			PingFrame,
			GoawayFrame,
			WindowUpdateFrame,
			ContinuationFrame,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			PriorityUpdateFrame,
		].freeze
		
		# Default connection "fast-fail" preamble string as defined by the spec.
		CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".freeze
		
		# Handles frame serialization and deserialization for HTTP/2 connections.
		# This class manages the reading and writing of HTTP/2 frames to/from a stream.
		class Framer
			# Initialize a new framer with a stream and frame definitions.
			# @parameter stream [IO] The underlying stream for frame I/O.
			# @parameter frames [Array] Frame type definitions to use.
			def initialize(stream, frames = FRAMES)
				@stream = stream
				@frames = frames
			end
			
			# Flush the underlying stream.
			def flush
				@stream.flush
			end
			
			# Close the underlying stream.
			def close
				@stream.close
			end
			
			# Check if the underlying stream is closed.
			# @returns [Boolean] True if the stream is closed.
			def closed?
				@stream.closed?
			end
			
			# Write the HTTP/2 connection preface to the stream.
			def write_connection_preface
				@stream.write(CONNECTION_PREFACE)
			end
			
			# Read and validate the HTTP/2 connection preface from the stream.
			# @raises [HandshakeError] If the preface is invalid.
			def read_connection_preface
				string = @stream.read(CONNECTION_PREFACE.bytesize)
				
				unless string == CONNECTION_PREFACE
					raise HandshakeError, "Invalid connection preface: #{string.inspect}"
				end
				
				return string
			end
			
			# @return [Frame] the frame that has been read from the underlying IO.
			# @raise if the underlying IO fails for some reason.
			def read_frame(maximum_frame_size = MAXIMUM_ALLOWED_FRAME_SIZE)
				# Read the header:
				length, type, flags, stream_id = read_header
				
				# Console.debug(self) {"read_frame: length=#{length} type=#{type} flags=#{flags} stream_id=#{stream_id} -> klass=#{@frames[type].inspect}"}
				
				# Allocate the frame:
				klass = @frames[type] || Frame
				frame = klass.new(stream_id, flags, type, length)
				
				# Read the payload:
				frame.read(@stream, maximum_frame_size)
				
				# Console.debug(self, name: "read") {frame.inspect}
				
				return frame
			end
			
			# Write a frame to the underlying IO.
			# After writing one or more frames, you should call flush to ensure the frames are sent to the remote peer.
			# @parameter frame [Frame] the frame to write.
			def write_frame(frame)
				# Console.debug(self, name: "write") {frame.inspect}
				
				frame.write(@stream)
				
				return frame
			end
			
			# Read a frame header from the stream.
			# @returns [Array] Parsed frame header components: length, type, flags, stream_id.
			# @raises [EOFError] If the header cannot be read completely.
			def read_header
				if buffer = @stream.read(9)
					if buffer.bytesize == 9
						return Frame.parse_header(buffer)
					end
				end
				
				raise EOFError, "Could not read frame header!"
			end
		end
	end
end
