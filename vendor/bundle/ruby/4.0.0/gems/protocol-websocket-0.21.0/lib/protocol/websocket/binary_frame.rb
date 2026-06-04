# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2021, by Aurora Nockert.

require_relative "frame"
require_relative "message"

module Protocol
	module WebSocket
		# Represents a binary frame that is sent or received by a WebSocket connection.
		class BinaryFrame < Frame
			OPCODE = 0x2
			
			# @returns [Boolean] if the frame contains data.
			def data?
				true
			end
			
			# Decode the binary buffer into a suitable binary message.
			# @parameter buffer [String] The binary data to unpack.
			def read_message(buffer)
				return BinaryMessage.new(buffer)
			end
			
			# Apply this frame to the specified connection.
			def apply(connection)
				connection.receive_binary(self)
			end
		end
	end
end
