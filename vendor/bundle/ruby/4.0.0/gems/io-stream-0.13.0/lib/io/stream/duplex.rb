# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module IO::Stream
	# A low-level duplex IO adapter that composes distinct readable and writable endpoints.
	class Duplex
		# Initialize a duplex transport from separate readable and writable endpoints.
		# @parameter input [IO] The readable endpoint.
		# @parameter output [IO] The writable endpoint.
		def initialize(input, output = input)
			@input = input
			@output = output
		end
		
		attr :input
		attr :output
		
		# Return the underlying IO used to represent this duplex stream.
		# @returns [IO] The readable endpoint if available, otherwise the writable endpoint.
		def to_io
			@input || @output
		end
		
		# Return the maximum timeout across both endpoints.
		# @returns [Numeric | Nil] The effective timeout, or `nil` if no timeout is configured.
		def timeout
			[@input.timeout, @output.timeout].compact.max
		end
		
		# Update the timeout on both endpoints.
		# @parameter duration [Numeric | Nil] The timeout to assign.
		def timeout=(duration)
			@input.timeout = duration
			@output.timeout = duration
		end
		
		# Check whether both endpoints are closed.
		# @returns [Boolean] True if the duplex stream can no longer read or write.
		def closed?
			@input.closed? && @output.closed?
		end
		
		# Close the readable endpoint.
		def close_read
			return if @input.closed?
			
			if @input.respond_to?(:close_read)
				@input.close_read
			else
				@input.close
			end
		end
		
		# Close the writable endpoint.
		def close_write
			return if @output.closed?
			
			if @output.respond_to?(:close_write)
				@output.close_write
			else
				@output.close
			end
		end
		
		# Check whether the readable endpoint may still produce data.
		# @returns [Boolean] True if the readable endpoint reports it is readable.
		def readable?
			@input.readable?
		end
		
		# Close both endpoints.
		def close
			@output.close unless @output.closed?
			@input.close unless @input.closed?
		end
		
		# Write data to the writable endpoint.
		# @parameter buffer [String] The data to write.
		# @returns [Integer] The number of bytes written.
		def write(buffer)
			@output.write(buffer)
		end
		
		# Read data from the readable endpoint without blocking.
		# @parameter size [Integer] The maximum number of bytes to read.
		# @parameter buffer [String] The destination buffer.
		# @parameter exception [Boolean] Whether to raise on `:wait_readable` and EOF conditions.
		# @returns [String | Symbol | Nil] Data read from the endpoint, or the underlying non-blocking result.
		def read_nonblock(size, buffer, exception: false)
			@input.read_nonblock(size, buffer, exception: exception)
		end
		
		# Wait until the readable endpoint can be read.
		# @parameter duration [Numeric | Nil] The maximum time to wait.
		# @returns [Boolean] True if the endpoint became readable.
		def wait_readable(duration = @timeout)
			@input.wait_readable(duration)
		end
		
		# Wait until the writable endpoint can be written.
		# @parameter duration [Numeric | Nil] The maximum time to wait.
		# @returns [Boolean] True if the endpoint became writable.
		def wait_writable(duration = @timeout)
			@output.wait_writable(duration)
		end
	end
	
	# Construct a buffered stream from either one duplex IO-like object or two separate endpoints.
	# @parameter input [IO] The duplex IO object, or the readable endpoint.
	# @parameter output [IO | Nil] The writable endpoint, when distinct from the readable endpoint.
	# @parameter options [Hash] Additional options passed to the buffered stream wrapper.
	# @returns [IO::Stream::Buffered] A buffered stream wrapping the supplied transport.
	def self.Duplex(input, output = nil, **options)
		if output
			Buffered.wrap(Duplex.new(input, output), **options)
		else
			::IO.Stream(input)
		end
	end
end
