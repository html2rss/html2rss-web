# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "readable"

module Protocol
	module HTTP
		module Body
			# A body which reads from a file.
			class File < Readable
				# The default block size.
				BLOCK_SIZE = 64*1024
				
				# The default mode for opening files.
				MODE = ::File::RDONLY | ::File::BINARY
				
				# Open a file at the given path.
				#
				# @parameter path [String] the path to the file.
				def self.open(path, *arguments, **options)
					self.new(::File.open(path, MODE), *arguments, **options)
				end
				
				# Initialize the file body with the given file.
				#
				# @parameter file [::File] the file to read from.
				# @parameter range [Range] the range of bytes to read from the file.
				# @parameter size [Integer] the size of the file, if known.
				# @parameter block_size [Integer] the block size to use when reading from the file.
				def initialize(file, range = nil, size: file.size, block_size: BLOCK_SIZE)
					@file = file
					@range = range
					
					@block_size = block_size
					
					if range
						@file.seek(range.min)
						@offset = range.min
						@length = @remaining = range.size
					else
						@file.seek(0)
						@offset = 0
						@length = @remaining = size
					end
				end
				
				# Close the file.
				#
				# @parameter error [Exception | Nil] the error that caused the file to be closed.
				def close(error = nil)
					@file.close
					@remaining = 0
					
					super
				end
				
				# @attribute [::File] file the file to read from.
				attr :file
				
				# @attribute [Integer] the offset to read from.
				attr :offset
				
				# @attribute [Integer] the number of bytes to read.
				attr :length
				
				# @returns [Boolean] whether more data should be read.
				def empty?
					@remaining == 0
				end
				
				# @returns [Boolean] whether the body is ready to be read, always true for files.
				def ready?
					true
				end
				
				# Returns a copy of the body, by duplicating the file descriptor, including the same range if specified.
				#
				# @returns [File] the duplicated body.
				def buffered
					self.class.new(@file.dup, @range, block_size: @block_size)
				end
				
				# Rewind the file to the beginning of the range.
				def rewind
					@file.seek(@offset)
					@remaining = @length
				end
				
				# @returns [Boolean] whether the body is rewindable, generally always true for seekable files.
				def rewindable?
					true
				end
				
				# Read the next chunk of data from the file.
				#
				# @returns [String | Nil] the next chunk of data, or nil if the file is fully read.
				def read
					if @remaining > 0
						amount = [@remaining, @block_size].min
						
						if chunk = @file.read(amount)
							@remaining -= chunk.bytesize
							
							return chunk
						end
					end
				end
				
				# def stream?
				# 	true
				# end
				
				# def call(stream)
				# 	IO.copy_stream(@file, stream, @remaining)
				# ensure
				# 	stream.close
				# end
				
				# Read all the remaining data from the file and return it as a single string.
				#
				# @returns [String] the remaining data.
				def join
					return "" if @remaining == 0
					
					buffer = @file.read(@remaining)
					
					@remaining = 0
					
					return buffer
				end
				
				# Inspect the file body.
				#
				# @returns [String] a string representation of the file body.
				def inspect
					if @offset > 0
						"#<#{self.class} #{@file.inspect} +#{@offset}, #{@remaining} bytes remaining>"
					else
						"#<#{self.class} #{@file.inspect}, #{@remaining} bytes remaining>"
					end
				end
			end
		end
	end
end
