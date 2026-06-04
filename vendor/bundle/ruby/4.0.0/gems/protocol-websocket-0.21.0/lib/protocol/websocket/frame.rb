# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2019, by Soumya.
# Copyright, 2021, by Aurora Nockert.
# Copyright, 2025, by Taleh Zaliyev.

require_relative "error"

module Protocol
	module WebSocket
		# Represents a single WebSocket frame as defined by RFC 6455.
		class Frame
			include Comparable
			
			RSV1 = 0b0100
			RSV2 = 0b0010
			RSV3 = 0b0001
			RESERVED = RSV1 | RSV2 | RSV3
			
			OPCODE = 0
			
			# @parameter mask [Boolean | String] An optional 4-byte string which is used to mask the payload.
			def initialize(finished = true, payload = nil, flags: 0, opcode: self.class::OPCODE, mask: false)
				if mask == true
					mask = SecureRandom.bytes(4)
				end
				
				@finished = finished
				@flags = flags
				@opcode = opcode
				@mask = mask
				@payload = payload
			end
			
			# Check whether the specified RSV flag bit is set on this frame.
			# @parameter value [Integer] The flag bitmask to test (e.g. `RSV1`).
			# @returns [Boolean] `true` if the flag bit is set.
			def flag?(value)
				@flags & value != 0
			end
			
			# Compare this frame to another frame by their array representation.
			# @parameter other [Frame] The frame to compare against.
			# @returns [Integer] A comparison result (-1, 0, or 1).
			def <=> other
				to_ary <=> other.to_ary
			end
			
			# Convert this frame to an array of its fields for comparison or inspection.
			# @returns [Array] An array of `[finished, flags, opcode, mask, payload]`.
			def to_ary
				[@finished, @flags, @opcode, @mask, @payload]
			end
			
			# Check whether this is a control frame (opcode has bit 3 set).
			# @returns [Boolean] `true` if this is a control frame.
			def control?
				@opcode & 0x8 != 0
			end
			
			# @returns [Boolean] if the frame contains data.
			def data?
				false
			end
			
			# Check whether this is the final frame in a message.
			# @returns [Boolean] `true` if the FIN bit is set.
			def finished?
				@finished == true
			end
			
			# Check whether this frame is a continuation fragment (FIN bit not set).
			# @returns [Boolean] `true` if the FIN bit is not set.
			def continued?
				@finished == false
			end
			
			# The generic frame header uses the following binary representation:
			#
			#  0                   1                   2                   3
			#  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
			# +-+-+-+-+-------+-+-------------+-------------------------------+
			# |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
			# |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
			# |N|V|V|V|       |S|             |   (if payload len==126/127)   |
			# | |1|2|3|       |K|             |                               |
			# +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
			# |     Extended payload length continued, if payload len == 127  |
			# + - - - - - - - - - - - - - - - +-------------------------------+
			# |                               |Masking-key, if MASK set to 1  |
			# +-------------------------------+-------------------------------+
			# | Masking-key (continued)       |          Payload Data         |
			# +-------------------------------- - - - - - - - - - - - - - - - +
			# :                     Payload Data continued ...                :
			# + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
			# |                     Payload Data continued ...                |
			# +---------------------------------------------------------------+
			
			attr_accessor :finished
			attr_accessor :flags
			attr_accessor :opcode
			attr_accessor :mask
			attr_accessor :payload
			
			# The byte length of the payload.
			# @returns [Integer | nil]
			def length
				@payload&.bytesize
			end
			
			if IO.const_defined?(:Buffer) && IO::Buffer.respond_to?(:for) && IO::Buffer.method_defined?(:xor!)
				private def mask_xor(data, mask)
					buffer = data.dup
					mask_buffer = IO::Buffer.for(mask)
					
					IO::Buffer.for(buffer) do |buffer|
						buffer.xor!(mask_buffer)
					end
					
					return buffer
				end
			else
				warn "IO::Buffer not available, falling back to slow implementation of mask_xor!"
				private def mask_xor(data, mask)
					result = String.new(encoding: Encoding::BINARY)
					
					for i in 0...data.bytesize do
						result << (data.getbyte(i) ^ mask.getbyte(i % 4))
					end
					
					return result
				end
			end
			
			# Pack the given data into this frame's payload, applying masking if configured.
			# @parameter data [String] The payload data to pack.
			# @returns [Frame] Returns `self`.
			def pack(data = "")
				if data.bytesize.bit_length > 63
					raise ProtocolError, "Frame length #{data.bytesize} bigger than allowed maximum!"
				end
				
				if @mask
					@payload = mask_xor(data, @mask)
				else
					@payload = data
				end
				
				return self
			end
			
			# Unpack the raw payload, removing masking if present.
			# @returns [String] The unmasked payload data.
			def unpack
				if @mask and !@payload.empty?
					return mask_xor(@payload, @mask)
				else
					return @payload
				end
			end
			
			# Apply this frame to the connection by dispatching it to the appropriate handler.
			# @parameter connection [Connection] The WebSocket connection to receive this frame.
			def apply(connection)
				connection.receive_frame(self)
			end
		end
	end
end
