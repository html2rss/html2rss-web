# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"
require_relative "padded"

module Protocol
	module HTTP2
		# DATA frames convey arbitrary, variable-length sequences of octets associated with a stream. One or more DATA frames are used, for instance, to carry HTTP request or response payloads.
		# 
		# DATA frames MAY also contain padding. Padding can be added to DATA frames to obscure the size of messages.
		# 
		# +---------------+
		# |Pad Length? (8)|
		# +---------------+-----------------------------------------------+
		# |                            Data (*)                         ...
		# +---------------------------------------------------------------+
		# |                           Padding (*)                       ...
		# +---------------------------------------------------------------+
		#
		class DataFrame < Frame
			include Padded
			
			TYPE = 0x0
			
			# Check if this frame marks the end of the stream.
			# @returns [Boolean] True if the END_STREAM flag is set.
			def end_stream?
				flag_set?(END_STREAM)
			end
			
			# Pack data into the frame, handling empty data as stream end.
			# @parameter data [String | Nil] The data to pack into the frame.
			# @parameter arguments [Array] Additional arguments passed to super.
			# @parameter options [Hash] Additional options passed to super.
			def pack(data, *arguments, **options)
				if data
					super
				else
					@length = 0
					set_flags(END_STREAM)
				end
			end
			
			# Apply this DATA frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_data(self)
			end
			
			# Provide a readable representation of the frame for debugging.
			# @returns [String] A formatted string representation of the frame.
			def inspect
				"\#<#{self.class} stream_id=#{@stream_id} flags=#{@flags} #{@length || 0}b>"
			end
		end
	end
end
