# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"
require_relative "padded"
require_relative "continuation_frame"

module Protocol
	module HTTP2
		# The HEADERS frame is used to open a stream, and additionally carries a header block fragment. HEADERS frames can be sent on a stream in the "idle", "reserved (local)", "open", or "half-closed (remote)" state.
		# 
		# +---------------+
		# |Pad Length? (8)|
		# +-+-------------+-----------------------------------------------+
		# |E|                 Stream Dependency? (31)                     |
		# +-+-------------+-----------------------------------------------+
		# |  Weight? (8)  |
		# +-+-------------+-----------------------------------------------+
		# |                   Header Block Fragment (*)                 ...
		# +---------------------------------------------------------------+
		# |                           Padding (*)                       ...
		# +---------------------------------------------------------------+
		#
		class HeadersFrame < Frame
			include Continued, Padded
			
			TYPE = 0x1
			
			# Check if this frame contains priority information.
			# @returns [Boolean] True if the PRIORITY flag is set.
			def priority?
				flag_set?(PRIORITY)
			end
			
			# Check if this frame ends the stream.
			# @returns [Boolean] True if the END_STREAM flag is set.
			def end_stream?
				flag_set?(END_STREAM)
			end
			
			# Unpack the header block fragment from the frame.
			# @returns [String] The unpacked header block data.
			def unpack
				data = super
				
				if priority?
					# We no longer support priority frames, so strip the data:
					data = data.byteslice(5, data.bytesize - 5)
				end
				
				return data
			end
			
			# Pack header block data into the frame.
			# @parameter data [String] The header block data to pack.
			# @parameter arguments [Array] Additional arguments.
			# @parameter options [Hash] Options for packing.
			def pack(data, *arguments, **options)
				buffer = String.new.b
				
				buffer << data
				
				super(buffer, *arguments, **options)
			end
			
			# Apply this HEADERS frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_headers(self)
			end
			
			# Get a string representation of the headers frame.
			# @returns [String] Human-readable frame information.
			def inspect
				"\#<#{self.class} stream_id=#{@stream_id} flags=#{@flags} #{@length || 0}b>"
			end
		end
	end
end
