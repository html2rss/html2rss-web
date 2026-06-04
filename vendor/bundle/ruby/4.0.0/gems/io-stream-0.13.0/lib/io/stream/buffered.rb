# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require_relative "generic"
require_relative "connection_reset_error"

module IO::Stream
	# A buffered stream implementation that wraps an underlying IO object to provide efficient buffered reading and writing.
	class Buffered < Generic
		# Open a file and wrap it in a buffered stream.
		# @parameter path [String] The file path to open.
		# @parameter mode [String] The file mode (e.g., "r+", "w", "a").
		# @parameter options [Hash] Additional options passed to the stream constructor.
		# @returns [IO::Stream::Buffered] A buffered stream wrapping the opened file.
		def self.open(path, mode = "r+", **options)
			stream = self.new(::File.open(path, mode), **options)
			
			return stream unless block_given?
			
			begin
				yield stream
			ensure
				stream.close
			end
		end
		
		# Wrap an existing IO object in a buffered stream.
		# @parameter io [IO] The IO object to wrap.
		# @parameter options [Hash] Additional options passed to the stream constructor.
		# @returns [IO::Stream::Buffered] A buffered stream wrapping the IO object.
		def self.wrap(io, **options)
			if io.respond_to?(:buffered=)
				io.buffered = false
			elsif io.respond_to?(:sync=)
				io.sync = true
			end
			
			stream = self.new(io, **options)
			
			return stream unless block_given?
			
			begin
				yield stream
			ensure
				stream.close
			end
		end
		
		# Initialize a new buffered stream.
		# @parameter io [IO] The underlying IO object to wrap.
		def initialize(io, ...)
			super(...)
			
			@io = io
			if io.respond_to?(:timeout)
				@timeout = io.timeout
			else
				@timeout = nil
			end
		end
		
		# @attribute [IO] The wrapped IO object.
		attr :io
		
		# Get the underlying IO object.
		# @returns [IO] The underlying IO object.
		def to_io
			@io.to_io
		end
		
		# Check if the stream is closed.
		# @returns [Boolean] True if the stream is closed.
		def closed?
			@io.closed?
		end
		
		# Close the read end of the stream.
		def close_read
			@io.close_read
		end
		
		# Close the write end of the stream.
		def close_write
			super
		ensure
			@io.close_write
		end
		
		# Check if the stream is readable.
		# @returns [Boolean] True if the stream is readable.
		def readable?
			super && @io.readable?
		end
		
		protected
		
		if RUBY_VERSION < "3.3.6"
			def sysclose
				# https://bugs.ruby-lang.org/issues/20723
				Thread.new{@io.close}.join
			end
		else
			def sysclose
				@io.close
			end
		end
		
		def syswrite(buffer)
			return @io.write(buffer)
		end
		
		# Reads data from the underlying stream as efficiently as possible.
		def sysread(size, buffer)
			# Come on Ruby, why couldn't this just return `nil`? EOF is not exceptional. Every file has one.
			while true
				result = @io.read_nonblock(size, buffer, exception: false)
				
				case result
				when :wait_readable
					@io.wait_readable(@io.timeout) or raise ::IO::TimeoutError, "read timeout"
				when :wait_writable
					@io.wait_writable(@io.timeout) or raise ::IO::TimeoutError, "write timeout"
				else
					return result
				end
			end
		rescue OpenSSL::SSL::SSLError => error
			if error.message =~ /unexpected eof while reading/
				raise ConnectionResetError, "Connection reset by peer!"
			end
		rescue Errno::ECONNRESET
			raise ConnectionResetError, "Connection reset by peer!"
		rescue Errno::EBADF
			raise ::IOError, "stream closed"
		end
	end
end
