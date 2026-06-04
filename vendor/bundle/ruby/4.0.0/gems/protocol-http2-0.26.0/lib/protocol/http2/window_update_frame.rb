# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"
require_relative "window"

module Protocol
	module HTTP2
		# The WINDOW_UPDATE frame is used to implement flow control.
		#
		# +-+-------------------------------------------------------------+
		# |R|              Window Size Increment (31)                     |
		# +-+-------------------------------------------------------------+
		#
		class WindowUpdateFrame < Frame
			TYPE = 0x8
			FORMAT = "N"
			
			# Pack a window size increment into the frame.
			# @parameter window_size_increment [Integer] The window size increment value.
			def pack(window_size_increment)
				super [window_size_increment].pack(FORMAT)
			end
			
			# Unpack the window size increment from the frame payload.
			# @returns [Integer] The window size increment value.
			def unpack
				super.unpack1(FORMAT)
			end
			
			# Read and validate the WINDOW_UPDATE frame payload.
			# @parameter stream [IO] The stream to read from.
			# @raises [FrameSizeError] If the frame length is invalid.
			def read_payload(stream)
				super
				
				if @length != 4
					raise FrameSizeError, "Invalid frame length: #{@length} != 4!"
				end
			end
			
			# Apply this WINDOW_UPDATE frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_window_update(self)
			end
		end
	end
end
