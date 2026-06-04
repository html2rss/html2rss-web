# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "string_buffer"

module IO::Stream
	# The default block size for IO buffers. Defaults to 256KB (optimized for modern SSDs and networks).
	BLOCK_SIZE = ENV.fetch("IO_STREAM_BLOCK_SIZE", 1024*256).to_i
	
	# The minimum read size for efficient I/O operations. Defaults to the same as BLOCK_SIZE.
	MINIMUM_READ_SIZE = ENV.fetch("IO_STREAM_MINIMUM_READ_SIZE", BLOCK_SIZE).to_i
	
	# The maximum read size for a single read operation. This limit exists because:
	# 1. System calls like read() cannot handle requests larger than SSIZE_MAX
	# 2. Very large reads can cause memory pressure and poor interactive performance  
	# 3. Most socket buffers and pipe capacities are much smaller anyway
	# On 64-bit systems SSIZE_MAX is ~8.8 million MB, on 32-bit it's ~2GB.
	# Our default of 16MB provides a good balance of throughput and responsiveness, and is page aligned.
	# It is also a multiple of the minimum read size, so that we can read in chunks without exceeding the maximum.
	MAXIMUM_READ_SIZE = ENV.fetch("IO_STREAM_MAXIMUM_READ_SIZE", MINIMUM_READ_SIZE * 64).to_i
	
	# A module providing readable stream functionality.
	#
	# You must implement the `sysread` method to read data from the underlying IO.
	module Readable
		ASYNC_SAFE = {
			read: :readable,
			read_partial: :readable,
			read_exactly: :readable,
			read_until: :readable,
			peek: :readable,
			gets: :readable,
			getc: :readable,
			getbyte: :readable,
			readline: :readable,
			readlines: :readable,
			readable?: :readable,
			fill_read_buffer: :readable,
			eof?: :readable,
			finished?: :readable,
		}.freeze
		
		# Check if a method is async-safe.
		#
		# @parameter method [Symbol] The method name to check.
		# @returns [Symbol | Boolean] The concurrency guard for the given method.
		def self.async_safe?(method)
			ASYNC_SAFE.fetch(method, false)
		end
		
		# Initialize readable stream functionality.
		# @parameter minimum_read_size [Integer] The minimum size for read operations.
		# @parameter maximum_read_size [Integer] The maximum size for read operations.
		# @parameter block_size [Integer] Legacy parameter, use minimum_read_size instead.
		def initialize(minimum_read_size: MINIMUM_READ_SIZE, maximum_read_size: MAXIMUM_READ_SIZE, block_size: nil, **, &block)
			@finished = false
			@read_buffer = StringBuffer.new
			# Used as destination buffer for underlying reads.
			@input_buffer = StringBuffer.new
			
			# Support legacy block_size parameter for backwards compatibility
			@minimum_read_size = block_size || minimum_read_size
			@maximum_read_size = maximum_read_size
			
			super(**, &block) if defined?(super)
		end
		
		attr_accessor :minimum_read_size
		
		# Legacy accessor for backwards compatibility
		# @returns [Integer] The minimum read size.
		def block_size
			@minimum_read_size
		end
		
		# Legacy setter for backwards compatibility
		# @parameter value [Integer] The minimum read size.
		def block_size=(value)
			@minimum_read_size = value
		end
		
		# Read data from the stream.
		# @parameter size [Integer | Nil] The number of bytes to read. If nil, read until end of stream.
		# @parameter buffer [String | Nil] An optional buffer to fill with data instead of allocating a new string.
		# @returns [String] The data read from the stream, or the provided buffer filled with data.
		def read(size = nil, buffer = nil)
			if size == 0
				if buffer
					buffer.clear
					buffer.force_encoding(Encoding::BINARY)
					return buffer
				else
					return String.new(encoding: Encoding::BINARY)
				end
			end
			
			if size
				until @finished or @read_buffer.bytesize >= size
					# Compute the amount of data we need to read from the underlying stream:
					read_size = size - @read_buffer.bytesize
					
					# Don't read less than @minimum_read_size to avoid lots of small reads:
					fill_read_buffer(read_size > @minimum_read_size ? read_size : @minimum_read_size)
				end
			else
				until @finished
					fill_read_buffer
				end
				
				if buffer
					buffer.replace(@read_buffer)
					@read_buffer.clear
				else
					buffer = @read_buffer
					@read_buffer = StringBuffer.new
				end
				
				# Read without size always returns a non-nil value, even if it is an empty string.
				return buffer
			end
			
			return consume_read_buffer(size, buffer)
		end
		
		# Read at most `size` bytes from the stream. Will avoid reading from the underlying stream if possible.
		# @parameter size [Integer | Nil] The number of bytes to read. If nil, read all available data.
		# @parameter buffer [String | Nil] An optional buffer to fill with data instead of allocating a new string.
		# @returns [String] The data read from the stream, or the provided buffer filled with data.
		def read_partial(size = nil, buffer = nil)
			if size == 0
				if buffer
					buffer.clear
					buffer.force_encoding(Encoding::BINARY)
					return buffer
				else
					return String.new(encoding: Encoding::BINARY)
				end
			end
			
			if !@finished and @read_buffer.empty?
				fill_read_buffer
			end
			
			return consume_read_buffer(size, buffer)
		end
		
		# Read exactly the specified number of bytes.
		# @parameter size [Integer] The number of bytes to read.
		# @parameter exception [Class] The exception to raise if not enough data is available.
		# @returns [String] The data read from the stream.
		def read_exactly(size, buffer = nil, exception: EOFError)
			if buffer = read(size, buffer)
				if buffer.bytesize != size
					raise exception, "Could not read enough data!"
				end
				
				return buffer
			end
			
			raise exception, "Stream finished before reading enough data!"
		end
		
		# This is a compatibility shim for existing code that uses `readpartial`.
		# @parameter size [Integer | Nil] The number of bytes to read.
		# @parameter buffer [String | Nil] An optional buffer to fill with data instead of allocating a new string.
		# @returns [String] The data read from the stream.
		def readpartial(size = nil, buffer = nil)
			read_partial(size, buffer) or raise EOFError, "Stream finished before reading enough data!"
		end
		
		# Find the index of a pattern in the read buffer, reading more data if needed.
		# @parameter pattern [String] The pattern to search for.
		# @parameter offset [Integer] The offset to start searching from.
		# @parameter limit [Integer | Nil] The maximum number of bytes to read while searching.
		# @returns [Integer | Nil] The index of the pattern, or nil if not found.
		private def index_of(pattern, offset, limit, discard = false)
			# We don't want to split on the pattern, so we subtract the size of the pattern.
			split_offset = pattern.bytesize - 1
			
			until index = @read_buffer.index(pattern, offset)
				offset = @read_buffer.bytesize - split_offset
				
				offset = 0 if offset < 0
				
				if limit and offset >= limit
					return nil
				end
				
				unless fill_read_buffer
					return nil
				end
				
				if discard
					# If we are discarding, we should consume the read buffer up to the offset:
					consume_read_buffer(offset)
					offset = 0
				end
			end
			
			return index
		end
		
		# Efficiently read data from the stream until encountering pattern.
		# @parameter pattern [String] The pattern to match.
		# @parameter offset [Integer] The offset to start searching from.
		# @parameter limit [Integer] The maximum number of bytes to read, including the pattern (even if chomped).
		# @parameter chomp [Boolean] Whether to remove the pattern from the returned data.
		# @returns [String | Nil] The contents of the stream up until the pattern, or nil if the pattern was not found. 
		def read_until(pattern, offset = 0, limit: nil, chomp: true)
			if index = index_of(pattern, offset, limit)
				return nil if limit and index >= limit
				
				@read_buffer.freeze
				matched = @read_buffer.byteslice(0, index+(chomp ? 0 : pattern.bytesize))
				@read_buffer = @read_buffer.byteslice(index+pattern.bytesize, @read_buffer.bytesize)
				
				return matched
			end
		end
		
		# Efficiently discard data from the stream until encountering pattern.
		# @parameter pattern [String] The pattern to match.
		# @parameter offset [Integer] The offset to start searching from.
		# @parameter limit [Integer] The maximum number of bytes to read, including the pattern.
		# @returns [String | Nil] The contents of the stream up until the pattern, or nil if the pattern was not found.
		def discard_until(pattern, offset = 0, limit: nil)
			if index = index_of(pattern, offset, limit, true)
				@read_buffer.freeze
				
				if limit and index >= limit
					@read_buffer = @read_buffer.byteslice(limit, @read_buffer.bytesize)
					
					return nil
				end
				
				matched = @read_buffer.byteslice(0, index+pattern.bytesize)
				@read_buffer = @read_buffer.byteslice(index+pattern.bytesize, @read_buffer.bytesize)
				
				return matched
			end
		end
		
		# Peek at data in the buffer without consuming it.
		# @parameter size [Integer | Nil] The number of bytes to peek at. If nil, peek at all available data.
		# @returns [String] The data in the buffer without consuming it.
		def peek(size = nil)
			if size
				until @finished or @read_buffer.bytesize >= size
					# Compute the amount of data we need to read from the underlying stream:
					read_size = size - @read_buffer.bytesize
					
					# Don't read less than @minimum_read_size to avoid lots of small reads:
					fill_read_buffer(read_size > @minimum_read_size ? read_size : @minimum_read_size)
				end
				
				return @read_buffer[..([size, @read_buffer.size].min - 1)]
			end
			
			until (block_given? && yield(@read_buffer)) or @finished
				fill_read_buffer
			end
			
			return @read_buffer
		end
		
		# Read a line from the stream, similar to IO#gets.
		# @parameter separator [String] The line separator to search for.
		# @parameter limit [Integer | Nil] The maximum number of bytes to read.
		# @parameter chomp [Boolean] Whether to remove the separator from the returned line.
		# @returns [String | Nil] The line read from the stream, or nil if at end of stream.
		def gets(separator = $/, limit = nil, chomp: false)
			# Compatibility with IO#gets:
			if separator.is_a?(Integer)
				limit = separator
				separator = $/
			end
			
			# We don't want to split in the middle of the separator, so we subtract the size of the separator from the start of the search:
			split_offset = separator.bytesize - 1
			
			offset = 0
			
			until index = @read_buffer.index(separator, offset)
				offset = @read_buffer.bytesize - split_offset
				offset = 0 if offset < 0
				
				# If a limit was given, and the offset is beyond the limit, we should return up to the limit:
				if limit and offset >= limit
					# As we didn't find the separator, there is nothing to chomp either.
					return consume_read_buffer(limit)
				end
				
				# If we can't read any more data, we should return what we have:
				return consume_read_buffer unless fill_read_buffer
			end
			
			# If the index of the separator was beyond the limit:
			if limit and index >= limit
				# Return up to the limit:
				return consume_read_buffer(limit)
			end
			
			# Freeze the read buffer, as this enables us to use byteslice without generating a hidden copy:
			@read_buffer.freeze
			
			line = @read_buffer.byteslice(0, index+(chomp ? 0 : separator.bytesize))
			@read_buffer = @read_buffer.byteslice(index+separator.bytesize, @read_buffer.bytesize)
			
			return line
		end
		
		# Determins if the stream has consumed all available data. May block if the stream is not readable.
		# See {readable?} for a non-blocking alternative.
		#
		# @returns [Boolean] If the stream is at file which means there is no more data to be read.
		def finished?
			if !@read_buffer.empty?
				return false
			elsif @finished
				return true
			else
				return !self.fill_read_buffer
			end
		end
		
		alias eof? finished?
		
		# Mark the stream as finished and raise `EOFError`.
		def finish!
			@read_buffer.clear
			@finished = true
			
			raise EOFError
		end
		
		alias eof! finish!
		
		# Whether there is a chance that a read operation will succeed or not.
		# @returns [Boolean] If the stream is readable, i.e. a `read` operation has a chance of success.
		def readable?
			# If we are at the end of the file, we can't read any more data:
			if @finished
				return false
			end
			
			# If the read buffer is not empty, we can read more data:
			if !@read_buffer.empty?
				return true
			end
			
			# If the underlying stream is readable, we can read more data:
			return !closed?
		end
		
		# Close the read end of the stream.
		def close_read
		end
		
		private
		
		# Fills the buffer from the underlying stream.
		def fill_read_buffer(size = @minimum_read_size)
			# Limit the read size to avoid exceeding SSIZE_MAX and to manage memory usage.
			# Very large reads can also hurt interactive performance by blocking for too long.
			if size > @maximum_read_size
				size = @maximum_read_size
			end
			
			# This effectively ties the input and output stream together.
			self.flush
			
			if @read_buffer.empty?
				if sysread(size, @read_buffer)
					# Console.info(self, name: "read") {@read_buffer.inspect}
					return true
				end
			else
				if chunk = sysread(size, @input_buffer)
					@read_buffer << chunk
					# Console.info(self, name: "read") {@read_buffer.inspect}
					
					return true
				end
			end
			
			# else for both cases above:
			@finished = true
			return false
		end
		
		# Consumes at most `size` bytes from the buffer.
		# @parameter size [Integer | Nil] The amount of data to consume. If nil, consume entire buffer.
		# @parameter buffer [String | Nil] An optional buffer to fill with data instead of allocating a new string.
		# @returns [String | Nil] The consumed data, or nil if no data available.
		def consume_read_buffer(size = nil, buffer = nil)
			# If we are at finished, and the read buffer is empty, we can't consume anything.
			if @finished && @read_buffer.empty?
				# Clear the buffer even when returning nil
				if buffer
					buffer.clear
					buffer.force_encoding(Encoding::BINARY)
				end
				return nil
			end
			
			result = nil
			
			if size.nil? or size >= @read_buffer.bytesize
				# Consume the entire read buffer:
				if buffer
					buffer.clear
					buffer << @read_buffer
					result = buffer
				else
					result = @read_buffer
				end
				@read_buffer = StringBuffer.new
			else
				# We know that we are not going to reuse the original buffer.
				# But byteslice will generate a hidden copy. So let's freeze it first:
				@read_buffer.freeze
				
				if buffer
					# Use replace instead of clear + << for better performance
					buffer.replace(@read_buffer.byteslice(0, size))
					result = buffer
				else
					result = @read_buffer.byteslice(0, size)
				end
				@read_buffer = @read_buffer.byteslice(size, @read_buffer.bytesize)
			end
			
			return result
		end
	end
end
