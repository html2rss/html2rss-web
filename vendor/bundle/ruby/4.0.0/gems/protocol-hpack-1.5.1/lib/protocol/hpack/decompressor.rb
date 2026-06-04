# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2024, by Maruth Goyal.
# Copyright, 2024, by Nathan Froyd.

require_relative "context"
require_relative "huffman"

module Protocol
	module HPACK
		# Responsible for decoding received headers and maintaining compression
		# context of the opposing peer. Decompressor must be initialized with
		# appropriate starting context based on local role: client or server.
		class Decompressor
			
			MASK_SHIFT_4 = (~0x0 >> 4) << 4

			def initialize(buffer, context = Context.new, table_size_limit: nil)
				@buffer = buffer
				@context = context
				@offset = 0
				
				@table_size_limit = table_size_limit
			end

			attr :buffer
			attr :context
			attr :offset
			
			attr :table_size_limit
			
			def end?
				@offset >= @buffer.bytesize
			end

			def read_byte
				if byte = @buffer.getbyte(@offset)
					@offset += 1
				end
				
				return byte
			end
			
			def peek_byte
				@buffer.getbyte(@offset)
			end

			def read_bytes(length)
				slice = @buffer.byteslice(@offset, length)
				
				@offset += length
				
				return slice
			end

			# Decodes integer value from provided buffer.
			#
			# @param bits [Integer] number of available bits
			# @return [Integer]
			def read_integer(bits)
				limit = 2**bits - 1
				value = bits.zero? ? 0 : (read_byte & limit)
				
				shift = 0
				
				while byte = read_byte
					value += ((byte & 127) << shift)
					shift += 7
					
					break if (byte & 128).zero?
				end if (value == limit)
				
				return value
			end

			# Decodes string value from provided buffer.
			#
			# @return [String] UTF-8 encoded string
			# @raise [CompressionError] when input is malformed
			def read_string
				huffman = (peek_byte & 0x80) == 0x80
				
				length = read_integer(7)
				
				raise CompressionError, "Invalid string length!" unless length
				
				string = read_bytes(length)
				
				raise CompressionError, "Invalid string length, got #{string.bytesize}, expecting #{length}!" unless string.bytesize == length
				
				string = Huffman.decode(string) if huffman
				
				return string.force_encoding(Encoding::UTF_8)
			end

			# Decodes header command from provided buffer.
			#
			# @param buffer [Buffer]
			# @return [Hash] command
			def read_header
				pattern = peek_byte

				header = {}

				type = nil

				# (pattern & MASK_SHIFT_4) clears bottom 4 bits,
				# equivalent to (pattern >> 4) << 4. For the
				# no-index and never-indexed type we only need to clear
				# the bottom 4 bits (as specified by NO_INDEX_TYPE[:prefix])
				# so we directly check against NO_INDEX_TYPE[:pattern].
				# But for change-table-size, incremental, and indexed
				# we must clear 5,6, and 7 bits respectively.
				# Consider indexed where we need to clear 7 bits.
				# Since (pattern & MASK_SHIFT_4)'s bottom 4 bits are cleared
				# you can visualize it as
				#
				# INDEXED_TYPE[:pattern] = <some bits>      0  0  0  0 0 0 0
				#                                           ^^^^^^^^^^^^^^^^ 7 bits
				# (pattern & MASK_SHIFT_4) = <pattern bits> b1 b2 b3 0 0 0 0
				#
				# Computing equality after masking bottom 7 bits (i.e., set b1 = b2 = b3 = 0)
				# is the same as checking equality against
				#                 <some bits> x1 x2 x3 0 0 0 0
				# For *every* possible value of x1, x2, x3 (that is, 2^3 = 8 values).
				# INDEXED_TYPE[:pattern] = 0x80, so we check against 0x80, 0x90 = 0x80 + (0b001 << 4)
				# 0xa0 = 0x80 + (0b001 << 5), ..., 0xf0 = 0x80 + (0b111 << 4).
				# While not the most readable, we have written out everything as constant literals
				# so Ruby can optimize this case-when to a hash lookup.
				#
				# There's no else case as this list is exhaustive.
				# (0..255).map { |x| (x & -16).to_s(16) }.uniq will show this

				case (pattern & MASK_SHIFT_4)
				when 0x00
					header[:type] = :no_index
					type = NO_INDEX_TYPE
				when 0x10
					header[:type] = :never_indexed
					type = NEVER_INDEXED_TYPE
				# checking if (pattern >> 5) << 5 == 0x20
				# Since we cleared bottom 4 bits, the 5th
				# bit can be either 0 or 1, so check both
				# cases.
				when 0x20, 0x30
					header[:type] = :change_table_size
					type = CHANGE_TABLE_SIZE_TYPE
				# checking if (pattern >> 6) << 6 == 0x40
				# Same logic as above, but now over the 4
				# possible combinations of 2 bits (5th, 6th)
				when 0x40, 0x50, 0x60, 0x70
					header[:type] = :incremental
					type = INCREMENTAL_TYPE
				# checking if (pattern >> 7) << 7 == 0x80
				when 0x80, 0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0
					header[:type] = :indexed
					type = INDEXED_TYPE
				end

				header_name = read_integer(type[:prefix])

				case header[:type]
				when :indexed
					raise CompressionError if header_name.zero?
					header[:name] = header_name - 1
				when :change_table_size
					header[:name] = header_name
					header[:value] = header_name
					
					if @table_size_limit and header[:value] > @table_size_limit
						raise CompressionError, "Table size #{header[:value]} exceeds limit #{@table_size_limit}!"
					end
				else
					if header_name.zero?
						header[:name] = read_string
					else
						header[:name] = header_name - 1
					end
					
					header[:value] = read_string
				end

				return header
			end

			# Decodes and processes header commands within provided buffer.
			#
			# @param buffer [Buffer]
			# @return [Array] +[[name, value], ...]+
			def decode(list = [])
				while !end?
					command = read_header
					
					if pair = @context.decode(command)
						list << pair
					end
				end
				
				if command and command[:type] == :change_table_size
					raise CompressionError, "Trailing table size update!"
				end
				
				return list
			end
		end
	end
end
