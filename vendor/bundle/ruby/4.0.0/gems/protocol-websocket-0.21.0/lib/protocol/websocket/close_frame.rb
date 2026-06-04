# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2021, by Aurora Nockert.

require_relative "frame"

module Protocol
	module WebSocket
		# Represents a close frame that is sent or received by a WebSocket connection.
		class CloseFrame < Frame
			OPCODE = 0x8
			FORMAT = "na*"
			
			# Unpack the frame data into a close code and reason.
			# @returns [Tuple(Integer, String)] The close code and reason.
			def unpack
				data = super
				
				case data.length
				when 0
					[nil, nil]
				when 1
					raise ProtocolError, "Invalid close frame length!"
				else
					code, reason = *data.unpack(FORMAT)
					
					case code
					when 0 .. 999, 1005 .. 1006, 1015, 5000 .. 0xFFFF
						raise ProtocolError, "Invalid close code!"
					when 1004, 1016 .. 2999
						raise ProtocolError, "Reserved close code!"
					end
					
					reason.force_encoding(Encoding::UTF_8)
					
					unless reason.valid_encoding?
						raise ProtocolError, "Invalid UTF-8 in close reason!"
					end
					
					[code, reason]
				end
			end
			
			# Pack a close code and reason into the frame data.
			# If code is missing, reason is ignored.
			# @parameter code [Integer | Nil] The close code.
			# @parameter reason [String | Nil] The close reason.
			def pack(code = nil, reason = nil)
				if code
					if reason and reason.encoding != Encoding::UTF_8
						reason = reason.encode(Encoding::UTF_8)
					end
					
					super([code, reason].pack(FORMAT))
				else
					super()
				end
			end
			
			# Generate a suitable reply.
			# @returns [CloseFrame]
			def reply(code = Error::NO_ERROR, reason = "")
				frame = CloseFrame.new
				frame.pack(code, reason)
				return frame
			end
			
			# Apply this frame to the specified connection.
			def apply(connection)
				connection.receive_close(self)
			end
		end
	end
end
