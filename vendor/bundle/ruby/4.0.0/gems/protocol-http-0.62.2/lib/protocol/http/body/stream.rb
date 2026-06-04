# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2023, by Genki Takiuchi.
# Copyright, 2025, by William T. Nelson.

require_relative "buffered"

module Protocol
	module HTTP
		module Body
			# The input stream is an IO-like object which contains the raw HTTP POST data. When applicable, its external encoding must be "ASCII-8BIT" and it must be opened in binary mode, for Ruby 1.9 compatibility. The input stream must respond to gets, each, read and rewind.
			class Stream
				# The default line separator, used by {gets}.
				NEWLINE = "\n"
				
				# Initialize the stream with the given input and output.
				#
				# @parameter input [Readable] The input stream.
				# @parameter output [Writable] The output stream.
				def initialize(input = nil, output = Buffered.new)
					@input = input
					@output = output
					
					raise ArgumentError, "Non-writable output!" unless output.respond_to?(:write)
					
					# Will hold remaining data in `#read`.
					@buffer = nil
					
					@closed = false
					@closed_read = false
				end
				
				# @attribute [Readable] The input stream.
				attr :input
				
				# @attribute [Writable] The output stream.
				attr :output
				
				# This provides a read-only interface for data, which is surprisingly tricky to implement correctly.
				module Reader
					# Read data from the underlying stream.
					#
					# If given a non-negative length, it will read at most that many bytes from the stream. If the stream is at EOF, it will return nil.
					#
					# If the length is not given, it will read all data until EOF, or return an empty string if the stream is already at EOF.
					#
					# If buffer is given, then the read data will be placed into buffer instead of a newly created String object.
					#
					# @parameter length [Integer] the amount of data to read
					# @parameter buffer [String] the buffer which will receive the data
					# @returns [String] a buffer containing the data
					def read(length = nil, buffer = nil)
						if length == 0
							return (buffer ? buffer.clear : String.new(encoding: Encoding::BINARY))
						end
						
						buffer ||= String.new(encoding: Encoding::BINARY)
						
						# Take any previously buffered data and replace it into the given buffer.
						if @buffer
							buffer.replace(@buffer)
							@buffer = nil
						else
							buffer.clear
						end
						
						if length
							while buffer.bytesize < length and chunk = read_next
								buffer << chunk
							end
							
							# This ensures the subsequent `slice!` works correctly.
							buffer.force_encoding(Encoding::BINARY)
							
							# This will be at least one copy:
							@buffer = buffer.byteslice(length, buffer.bytesize)
							
							# This should be zero-copy:
							buffer.slice!(length, buffer.bytesize)
							
							if buffer.empty?
								return nil
							else
								return buffer
							end
						else
							while chunk = read_next
								buffer << chunk
							end
							
							return buffer
						end
					end
					
					# Read some bytes from the stream.
					#
					# If the length is given, at most length bytes will be read. Otherwise, one chunk of data from the underlying stream will be read.
					#
					# Will avoid reading from the underlying stream if there is buffered data available.
					#
					# @parameter length [Integer] The maximum number of bytes to read.
					def read_partial(length = nil, buffer = nil)
						if @buffer
							if buffer
								buffer.replace(@buffer)
							else
								buffer = @buffer
							end
							@buffer = nil
						else
							if chunk = read_next
								if buffer
									buffer.replace(chunk)
								else
									buffer = chunk
								end
							else
								buffer&.clear
								buffer = nil
							end
						end
						
						if buffer and length
							if buffer.bytesize > length
								# This ensures the subsequent `slice!` works correctly.
								buffer.force_encoding(Encoding::BINARY)
								
								@buffer = buffer.byteslice(length, buffer.bytesize)
								buffer.slice!(length, buffer.bytesize)
							end
						end
						
						return buffer
					end
					
					# Similar to {read_partial} but raises an `EOFError` if the stream is at EOF.
					#
					# @parameter length [Integer] The maximum number of bytes to read.
					# @parameter buffer [String] The buffer to read into.
					def readpartial(length, buffer = nil)
						read_partial(length, buffer) or raise EOFError, "End of file reached!"
					end
					
					# Iterate over each chunk of data from the input stream.
					#
					# @yields {|chunk| ...} Each chunk of data.
					def each(&block)
						return to_enum unless block_given?
						
						if @buffer
							yield @buffer
							@buffer = nil
						end
						
						while chunk = read_next
							yield chunk
						end
					end
					
					# Read data from the stream without blocking if possible.
					#
					# @parameter length [Integer] The maximum number of bytes to read.
					# @parameter buffer [String | Nil] The buffer to read into.
					def read_nonblock(length, buffer = nil, exception: nil)
						@buffer ||= read_next
						chunk = nil
						
						unless @buffer
							buffer&.clear
							return
						end
						
						if @buffer.bytesize > length
							chunk = @buffer.byteslice(0, length)
							@buffer = @buffer.byteslice(length, @buffer.bytesize)
						else
							chunk = @buffer
							@buffer = nil
						end
						
						if buffer
							buffer.replace(chunk)
						else
							buffer = chunk
						end
						
						return buffer
					end
					
					# Read data from the stream until encountering pattern.
					#
					# @parameter pattern [String] The pattern to match.
					# @parameter offset [Integer] The offset to start searching from.
					# @parameter chomp [Boolean] Whether to remove the pattern from the returned data.
					# @returns [String] The contents of the stream up until the pattern, which is consumed but not returned.
					def read_until(pattern, offset = 0, chomp: false)
						# We don't want to split on the pattern, so we subtract the size of the pattern.
						split_offset = pattern.bytesize - 1
						
						@buffer ||= read_next
						return nil if @buffer.nil?
						
						until index = @buffer.index(pattern, offset)
							offset = @buffer.bytesize - split_offset
							
							offset = 0 if offset < 0
							
							if chunk = read_next
								@buffer << chunk
							else
								return nil
							end
						end
						
						@buffer.freeze
						matched = @buffer.byteslice(0, index+(chomp ? 0 : pattern.bytesize))
						@buffer = @buffer.byteslice(index+pattern.bytesize, @buffer.bytesize)
						
						return matched
					end
					
					# Read a single line from the stream.
					#
					# @parameter separator [String] The line separator, defaults to `\n`.
					# @parameter limit [Integer] The maximum number of bytes to read.
					# @parameter *options [Hash] Additional options, passed to {read_until}.
					def gets(separator = NEWLINE, limit = nil, chomp: false)
						# If the separator is an integer, it is actually the limit:
						if separator.is_a?(Integer)
							limit = separator
							separator = NEWLINE
						end
						
						# If no separator is given, this is the same as a read operation:
						if separator.nil?
							# I tried using `read(limit)` here but it will block until the limit is reached, which is not usually desirable behaviour.
							return read_partial(limit)
						end
						
						# We don't want to split on the separator, so we subtract the size of the separator:
						split_offset = separator.bytesize - 1
						
						@buffer ||= read_next
						return nil if @buffer.nil?
						
						offset = 0
						until index = @buffer.index(separator, offset)
							offset = @buffer.bytesize - split_offset
							offset = 0 if offset < 0
							
							# If we have gone past the limit, we are done:
							if limit and offset >= limit
								@buffer.freeze
								matched = @buffer.byteslice(0, limit)
								@buffer = @buffer.byteslice(limit, @buffer.bytesize)
								return matched
							end
							
							# Read more data:
							if chunk = read_next
								@buffer << chunk
							else
								# No more data could be read, return the remaining data:
								buffer = @buffer
								@buffer = nil
								
								# Return nil for empty buffers, otherwise return the content:
								if buffer && !buffer.empty?
									return buffer
								else
									return nil
								end
							end
						end
						
						# Freeze the buffer, as this enables us to use byteslice without generating a hidden copy:
						@buffer.freeze
						
						if limit and index > limit
							line = @buffer.byteslice(0, limit)
							@buffer = @buffer.byteslice(limit, @buffer.bytesize)
						else
							line = @buffer.byteslice(0, index+(chomp ? 0 : separator.bytesize))
							@buffer = @buffer.byteslice(index+separator.bytesize, @buffer.bytesize)
						end
						
						return line
					end
				end
				
				include Reader
				
				# Write data to the underlying stream.
				#
				# @parameter buffer [String] The data to write.
				# @raises [IOError] If the stream is not writable.
				# @returns [Integer] The number of bytes written.
				def write(buffer)
					if @output
						@output.write(buffer)
						return buffer.bytesize
					else
						raise IOError, "Stream is not writable, output has been closed!"
					end
				end
				
				# Write data to the stream using {write}.
				#
				# Provided for compatibility with IO-like objects.
				#
				# @parameter buffer [String] The data to write.
				# @parameter exception [Boolean] Whether to raise an exception if the write would block, currently ignored.
				# @returns [Integer] The number of bytes written.
				def write_nonblock(buffer, exception: nil)
					write(buffer)
				end
				
				# Write data to the stream using {write}.
				def << buffer
					write(buffer)
				end
				
				# Write lines to the stream.
				#
				# The current implementation buffers the lines and writes them in a single operation.
				#
				# @parameter arguments [Array(String)] The lines to write.
				# @parameter separator [String] The line separator, defaults to `\n`.
				def puts(*arguments, separator: NEWLINE)
					buffer = ::String.new
					
					arguments.each do |argument|
						buffer << argument << separator
					end
					
					write(buffer)
				end
				
				# Flush the output stream.
				#
				# This is currently a no-op.
				def flush
				end
				
				# Close the input body.
				#
				# If, while processing the data that was read from this stream, an error is encountered, it should be passed to this method.
				#
				# @parameter error [Exception | Nil] The error that was encountered, if any.
				def close_read(error = nil)
					if input = @input
						@input = nil
						@closed_read = true
						@buffer = nil
						
						input.close(error)
					end
				end
				
				# Close the output body.
				#
				# If, while generating the data that is written to this stream, an error is encountered, it should be passed to this method.
				#
				# @parameter error [Exception | Nil] The error that was encountered, if any.
				def close_write(error = nil)
					if output = @output
						@output = nil
						
						output.close_write(error)
					end
				end
				
				# Close the input and output bodies.
				#
				# @parameter error [Exception | Nil] The error that caused this stream to be closed, if any.
				def close(error = nil)
					self.close_read(error)
					self.close_write(error)
					
					return nil
				ensure
					@closed = true
				end
				
				# @returns [Boolean] Whether the stream has been closed.
				def closed?
					@closed
				end
				
				# Inspect the stream.
				#
				# @returns [String] a string representation of the stream.
				def inspect
					buffer_info = @buffer ? "#{@buffer.bytesize} bytes buffered" : "no buffer"
					
					status = []
					status << "closed" if @closed
					status << "read-closed" if @closed_read
					
					status_info = status.empty? ? "open" : status.join(", ")
					
					return "#<#{self.class} #{buffer_info}, #{status_info}>"
				end
				
				# @returns [Boolean] Whether there are any output chunks remaining.
				def empty?
					@output.empty?
				end
				
				private
				
				# Read the next chunk of data from the input stream.
				#
				# @returns [String] The next chunk of data.
				# @raises [IOError] If the input stream was explicitly closed.
				def read_next
					if @input
						return @input.read
					elsif @closed_read
						raise IOError, "Stream is not readable, input has been closed!"
					end
				end
			end
		end
	end
end
