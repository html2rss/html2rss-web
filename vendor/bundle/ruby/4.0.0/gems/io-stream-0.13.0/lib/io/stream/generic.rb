# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require_relative "string_buffer"
require_relative "readable"
require_relative "writable"

require_relative "shim/buffered"
require_relative "shim/readable"
require_relative "shim/timeout"

require_relative "openssl"

module IO::Stream
	# Base class for stream implementations providing common functionality.
	class Generic
		include Readable
		include Writable
		
		# Check if a method is async-safe.
		#
		# @parameter method [Symbol] The method name to check.
		# @returns [Symbol | Boolean] The concurrency guard for the given method.
		def self.async_safe?(method)
			Readable.async_safe?(method) || Writable.async_safe?(method)
		end
		
		# Initialize a new generic stream.
		# @parameter options [Hash] Options passed to included modules.
		def initialize(**options)
			super(**options)
		end
		
		# Check if the stream is closed.
		# @returns [Boolean] False by default, should be overridden by subclasses.
		def closed?
			false
		end
		
		# Best effort to flush any unwritten data, and then close the underling IO.
		def close
			return if closed?
			
			begin
				self.flush
			rescue
				# We really can't do anything here unless we want #close to raise exceptions.
			ensure
				self.sysclose
			end
		end
		
		protected
		
		# Closes the underlying IO stream.
		# This method should be implemented by subclasses to handle the specific closing logic.
		def sysclose
			raise NotImplementedError
		end
		
		# Writes data to the underlying stream.
		# This method should be implemented by subclasses to handle the specific writing logic.
		# @parameter buffer [String] The data to write.
		# @returns [Integer] The number of bytes written.
		def syswrite(buffer)
			raise NotImplementedError
		end
		
		# Reads data from the underlying stream as efficiently as possible.
		# This method should be implemented by subclasses to handle the specific reading logic.
		def sysread(size, buffer)
			raise NotImplementedError
		end
	end
end
