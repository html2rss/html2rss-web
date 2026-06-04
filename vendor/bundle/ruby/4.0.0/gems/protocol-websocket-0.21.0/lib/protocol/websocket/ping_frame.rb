# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "frame"
require_relative "pong_frame"

module Protocol
	module WebSocket
		# Represents a ping frame that is sent or received by a WebSocket connection.
		class PingFrame < Frame
			OPCODE = 0x9
			
			# Generate a suitable reply.
			# @returns [PongFrame]
			def reply(**options)
				PongFrame.new(true, **options).pack(self.unpack)
			end
			
			# Apply this frame to the specified connection.
			def apply(connection)
				connection.receive_ping(self)
			end
		end
	end
end
