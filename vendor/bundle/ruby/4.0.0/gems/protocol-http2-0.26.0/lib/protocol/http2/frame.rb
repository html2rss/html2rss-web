# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2019, by Yuta Iwama.

require_relative "error"

module Protocol
	module HTTP2
		END_STREAM = 0x1
		END_HEADERS = 0x4
		PADDED = 0x8
		PRIORITY = 0x20
		
		MAXIMUM_ALLOWED_WINDOW_SIZE = 0x7FFFFFFF
		MINIMUM_ALLOWED_FRAME_SIZE = 0x4000
		MAXIMUM_ALLOWED_FRAME_SIZE = 0xFFFFFF
		
		# Represents the base class for all HTTP/2 frames.
		# This class provides common functionality for frame parsing, serialization,
		# and manipulation according to RFC 7540.
		class Frame
			include Comparable
			
			# Stream Identifier cannot be bigger than this:
			# https://http2.github.stream/http2-spec/#rfc.section.4.1
			VALID_STREAM_ID = 0..0x7fffffff
			
			# The absolute maximum bounds for the length field:
			VALID_LENGTH = 0..0xffffff
			
			# Used for generating 24-bit frame length:
			LENGTH_HISHIFT = 16
			LENGTH_LOMASK  = 0xFFFF
			
			# The base class does not have any specific type index:
			TYPE = nil
			
			# @parameter length [Integer] the length of the payload, or nil if the header has not been read yet.
			def initialize(stream_id = 0, flags = 0, type = self.class::TYPE, length = nil, payload = nil)
				@stream_id = stream_id
				@flags = flags
				@type = type
				@length = length
				@payload = payload
			end
			
			# Check if the frame has a valid type identifier.
			# @returns [Boolean] True if the frame type is valid.
			def valid_type?
				@type == self.class::TYPE
			end
			
			# Compare frames based on their essential properties.
			# @parameter other [Frame] The frame to compare with.
			# @returns [Integer] -1, 0, or 1 for comparison result.
			def <=> other
				to_ary <=> other.to_ary
			end
			
			# Convert frame to array representation for comparison.
			# @returns [Array] Frame properties as an array.
			def to_ary
				[@length, @type, @flags, @stream_id, @payload]
			end
			
			# The generic frame header uses the following binary representation:
			#
			# +-----------------------------------------------+
			# |                 Length (24)                   |
			# +---------------+---------------+---------------+
			# |   Type (8)    |   Flags (8)   |
			# +-+-------------+---------------+-------------------------------+
			# |R|                 Stream Identifier (31)                      |
			# +=+=============================================================+
			# |                   Frame Payload (0...)                      ...
			# +---------------------------------------------------------------+
			
			attr_accessor :length
			attr_accessor :type
			attr_accessor :flags
			attr_accessor :stream_id
			attr_accessor :payload
			
			# Unpack the frame payload data.
			# @returns [String] The frame payload.
			def unpack
				@payload
			end
			
			# Pack payload data into the frame.
			# @parameter payload [String] The payload data to pack.
			# @parameter maximum_size [Integer | Nil] Optional maximum payload size.
			# @raises [ProtocolError] If payload exceeds maximum size.
			def pack(payload, maximum_size: nil)
				@payload = payload
				@length = payload.bytesize
				
				if maximum_size and @length > maximum_size
					raise ProtocolError, "Frame length bigger than maximum allowed: #{@length} > #{maximum_size}"
				end
			end
			
			# Set specific flags on the frame.
			# @parameter mask [Integer] The flag bits to set.
			def set_flags(mask)
				@flags |= mask
			end
			
			# Clear specific flags on the frame.
			# @parameter mask [Integer] The flag bits to clear.
			def clear_flags(mask)
				@flags &= ~mask
			end
			
			# Check if specific flags are set on the frame.
			# @parameter mask [Integer] The flag bits to check.
			# @returns [Boolean] True if any of the flags are set.
			def flag_set?(mask)
				@flags & mask != 0
			end
			
			# Check if frame is a connection frame: SETTINGS, PING, GOAWAY, and any
			# frame addressed to stream ID = 0.
			#
			# @return [Boolean] If this is a connection frame.
			def connection?
				@stream_id.zero?
			end
			
			HEADER_FORMAT = "CnCCN".freeze
			STREAM_ID_MASK  = 0x7fffffff
			
			# Generates common 9-byte frame header.
			# - http://tools.ietf.org/html/draft-ietf-httpbis-http2-16#section-4.1
			#
			# @return [String]
			def header
				unless VALID_LENGTH.include? @length
					raise ProtocolError, "Invalid frame length: #{@length.inspect}"
				end
				
				unless VALID_STREAM_ID.include? @stream_id
					raise ProtocolError, "Invalid stream identifier: #{@stream_id.inspect}"
				end
				
				[
					# These are guaranteed correct due to the length check above.
					@length >> LENGTH_HISHIFT,
					@length & LENGTH_LOMASK,
					@type,
					@flags,
					@stream_id
				].pack(HEADER_FORMAT)
			end
			
			# Decodes common 9-byte header.
			#
			# @parameter buffer [String]
			def self.parse_header(buffer)
				length_hi, length_lo, type, flags, stream_id = buffer.unpack(HEADER_FORMAT)
				length = (length_hi << LENGTH_HISHIFT) | length_lo
				stream_id = stream_id & STREAM_ID_MASK
				
				# puts "parse_header: length=#{length} type=#{type} flags=#{flags} stream_id=#{stream_id}"
				
				return length, type, flags, stream_id
			end
			
			# Read the frame header from a stream.
			# @parameter stream [IO] The stream to read from.
			# @raises [EOFError] If the header cannot be read completely.
			def read_header(stream)
				if buffer = stream.read(9) and buffer.bytesize == 9
					@length, @type, @flags, @stream_id = Frame.parse_header(buffer)
					# puts "read_header: #{@length} #{@type} #{@flags} #{@stream_id}"
				else
					raise EOFError, "Could not read frame header!"
				end
			end
			
			# Read the frame payload from a stream.
			# @parameter stream [IO] The stream to read from.
			# @raises [EOFError] If the payload cannot be read completely.
			def read_payload(stream)
				if payload = stream.read(@length) and payload.bytesize == @length
					@payload = payload
				else
					raise EOFError, "Could not read frame payload!"
				end
			end
			
			# Read the complete frame (header and payload) from a stream.
			# @parameter stream [IO] The stream to read from.
			# @parameter maximum_frame_size [Integer] The maximum allowed frame size.
			# @raises [FrameSizeError] If the frame exceeds the maximum size.
			# @returns [Frame] Self for method chaining.
			def read(stream, maximum_frame_size = MAXIMUM_ALLOWED_FRAME_SIZE)
				read_header(stream) unless @length
				
				if @length > maximum_frame_size
					raise FrameSizeError, "#{self.class} (type=#{@type}) frame length #{@length} exceeds maximum frame size #{maximum_frame_size}!"
				end
				
				read_payload(stream)
			end
			
			# Write the frame header to a stream.
			# @parameter stream [IO] The stream to write to.
			def write_header(stream)
				stream.write self.header
			end
			
			# Write the frame payload to a stream.
			# @parameter stream [IO] The stream to write to.
			def write_payload(stream)
				stream.write(@payload) if @payload
			end
			
			# Write the complete frame (header and payload) to a stream.
			# @parameter stream [IO] The stream to write to.
			# @raises [ProtocolError] If frame validation fails.
			def write(stream)
				# Validate the payload size:
				if @payload.nil?
					if @length != 0
						raise ProtocolError, "Invalid frame length: #{@length} != 0"
					end
				else
					if @length != @payload.bytesize
						raise ProtocolError, "Invalid payload size: #{@length} != #{@payload.bytesize}"
					end
				end
				
				self.write_header(stream)
				self.write_payload(stream)
			end
			
			# Apply the frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_frame(self)
			end
			
			# Provide a readable representation of the frame for debugging.
			# @returns [String] A formatted string representation of the frame.
			def inspect
				"\#<#{self.class} stream_id=#{@stream_id} flags=#{@flags} payload=#{self.unpack}>"
			end
		end
	end
end
