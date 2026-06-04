# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "frame"

require_relative "continuation_frame"
require_relative "text_frame"
require_relative "binary_frame"
require_relative "close_frame"
require_relative "ping_frame"
require_relative "pong_frame"

module Protocol
	module WebSocket
		# HTTP/2 frame type mapping as defined by the spec.
		FRAMES = {
			0x0 => ContinuationFrame,
			0x1 => TextFrame,
			0x2 => BinaryFrame,
			0x8 => CloseFrame,
			0x9 => PingFrame,
			0xA => PongFrame,
		}.freeze
		
		# The maximum allowed frame size in bytes.
		MAXIMUM_ALLOWED_FRAME_SIZE = 2**63
		
		# Wraps an underlying {Async::IO::Stream} for reading and writing binary data into structured frames.
		class Framer
			# Initialize a new framer wrapping the given stream.
			# @parameter stream [IO] The underlying stream to read from and write to.
			# @parameter frames [Hash] A mapping of opcodes to frame classes.
			def initialize(stream, frames = FRAMES)
				@stream = stream
				@frames = frames
			end
			
			# Close the underlying stream.
			def close
				@stream.close
			end
			
			# Flush the underlying stream.
			def flush
				@stream.flush
			end
			
			# Read a frame from the underlying stream.
			# @returns [Frame] the frame read from the stream.
			def read_frame(maximum_frame_size = MAXIMUM_ALLOWED_FRAME_SIZE)
				buffer = @stream.read(2)
				
				unless buffer and buffer.bytesize == 2
					raise EOFError, "Could not read frame header!"
				end
				
				first_byte = buffer.getbyte(0)
				second_byte = buffer.getbyte(1)
				
				finished = (first_byte & 0b1000_0000 != 0)
				flags = (first_byte & 0b0111_0000) >> 4
				opcode = first_byte & 0b0000_1111
				
				if opcode >= 0x3 && opcode <= 0x7
					raise ProtocolError, "Non-control opcode = #{opcode} is reserved!"
				elsif opcode >= 0xB
					raise ProtocolError, "Control opcode = #{opcode} is reserved!"
				end
				
				mask = (second_byte & 0b1000_0000 != 0)
				length = second_byte & 0b0111_1111
				
				if opcode & 0x8 != 0
					if length > 125
						raise ProtocolError, "Invalid control frame payload length: #{length} > 125!"
					elsif !finished
						raise ProtocolError, "Fragmented control frame!"
					end
				end
				
				if length == 126
					if mask
						buffer = @stream.read(6) or raise EOFError, "Could not read length and mask!"
						length = buffer.unpack1("n")
						mask = buffer.byteslice(2, 4)
					else
						buffer = @stream.read(2) or raise EOFError, "Could not read length!"
						length = buffer.unpack1("n")
					end
				elsif length == 127
					if mask
						buffer = @stream.read(12) or raise EOFError, "Could not read length and mask!"
						length = buffer.unpack1("Q>")
						mask = buffer.byteslice(8, 4)
					else
						buffer = @stream.read(8) or raise EOFError, "Could not read length!"
						length = buffer.unpack1("Q>")
					end
				elsif mask
					mask = @stream.read(4) or raise EOFError, "Could not read mask!"
				end
				
				if length > maximum_frame_size
					raise ProtocolError, "Invalid payload length: #{length} > #{maximum_frame_size}!"
				end
				
				payload = @stream.read(length) or raise EOFError, "Could not read payload!"
				
				if payload.bytesize != length
					raise EOFError, "Incorrect payload length: #{length} != #{payload.bytesize}!"
				end
				
				klass = @frames[opcode] || Frame
				return klass.new(finished, payload, flags: flags, opcode: opcode, mask: mask)
			end
			
			# Write a frame to the underlying stream.
			# @parameter frame [Frame] The frame to serialize and write.
			# @raises [ProtocolError] If the frame has an invalid mask.
			def write_frame(frame)
				if frame.mask and frame.mask.bytesize != 4
					raise ProtocolError, "Invalid mask length!"
				end
				
				length = frame.length
				
				if length <= 125
					short_length = length
				elsif length.bit_length <= 16
					short_length = 126
				else
					short_length = 127
				end
				
				buffer = [
					(frame.finished ? 0b1000_0000 : 0) | (frame.flags << 4) | frame.opcode,
					(frame.mask ? 0b1000_0000 : 0) | short_length,
				].pack("CC")
				
				if short_length == 126
					buffer << [length].pack("n")
				elsif short_length == 127
					buffer << [length].pack("Q>")
				end
				
				buffer << frame.mask if frame.mask
				
				@stream.write(buffer)
				@stream.write(frame.payload)
			end
		end
	end
end
