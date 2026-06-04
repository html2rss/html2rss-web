# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "readable"

module IO::Stream
	# The minimum write size before flushing. Defaults to 64KB.
	MINIMUM_WRITE_SIZE = ENV.fetch("IO_STREAM_MINIMUM_WRITE_SIZE", BLOCK_SIZE).to_i
	
	# A module providing writable stream functionality.
	#
	# You must implement the `syswrite` method to write data to the underlying IO.
	module Writable
		ASYNC_SAFE = {
			write: true,
			puts: true,
			flush: true,
		}.freeze
		
		# Check if a method is async-safe.
		#
		# @parameter method [Symbol] The method name to check.
		# @returns [Symbol | Boolean] The concurrency guard for the given method.
		def self.async_safe?(method)
			ASYNC_SAFE.fetch(method, false)
		end
		
		# Initialize writable stream functionality.
		# @parameter minimum_write_size [Integer] The minimum buffer size before flushing.
		def initialize(minimum_write_size: MINIMUM_WRITE_SIZE, **, &block)
			@writing = ::Thread::Mutex.new
			@write_buffer = StringBuffer.new
			@minimum_write_size = minimum_write_size
			
			super(**, &block) if defined?(super)
		end
		
		attr_accessor :minimum_write_size
		
		# Flushes buffered data to the stream.
		def flush
			return if @write_buffer.empty?
			
			@writing.synchronize do
				self.drain(@write_buffer)
			end
		end
		
		# Writes `string` to the buffer. When the buffer is full or #sync is true the
		# buffer is flushed to the underlying `io`.
		# @parameter string [String] the string to write to the buffer.
		# @returns [Integer] the number of bytes appended to the buffer.
		def write(string, flush: false)
			@writing.synchronize do
				@write_buffer << string
				
				flush |= (@write_buffer.bytesize >= @minimum_write_size)
				
				if flush
					self.drain(@write_buffer)
				end
			end
			
			return string.bytesize
		end
		
		# Appends `string` to the buffer and returns self for method chaining.
		# @parameter string [String] the string to write to the stream.
		def <<(string)
			write(string)
			
			return self
		end
		
		# Write arguments to the stream followed by a separator and flush immediately.
		# @parameter arguments [Array] The arguments to write to the stream.
		# @parameter separator [String] The separator to append after each argument.
		def puts(*arguments, separator: $/)
			return if arguments.empty?
			
			@writing.synchronize do
				arguments.each do |argument|
					@write_buffer << argument << separator
				end
				
				self.drain(@write_buffer)
			end
		end
		
		# Close the write end of the stream by flushing any remaining data.
		def close_write
			flush
		end
		
		private def drain(buffer)
			begin
				syswrite(buffer)
			ensure
				# If the write operation fails, we still need to clear this buffer, and the data is essentially lost.
				buffer.clear
			end
		end
	end
end
