# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "frame"

module Protocol
	module WebSocket
		# Represents a continuation frame that is sent or received by a WebSocket connection when a message is split into multiple frames.
		class ContinuationFrame < Frame
			OPCODE = 0x0
			
			# Apply this frame to the specified connection.
			def apply(connection)
				connection.receive_continuation(self)
			end
		end
	end
end
