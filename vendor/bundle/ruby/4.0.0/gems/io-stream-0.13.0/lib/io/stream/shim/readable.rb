# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

class IO
	unless method_defined?(:readable?, false)
		# Check if the IO is readable.
		# @returns [Boolean] True if the IO is readable (not closed).
		def readable?
			# Do not call `eof?` here as it is not concurrency-safe and it can block.
			!closed?
		end
	end
end

require "socket"

class BasicSocket
	unless method_defined?(:readable?, false)
		# Check if the socket is readable.
		# @returns [Boolean] True if the socket is readable.
		def readable?
			# If we can wait for the socket to become readable, we know that the socket may still be open.
			result = self.recv_nonblock(1, ::Socket::MSG_PEEK, exception: false)
			
			# No data was available - newer Ruby can return nil instead of empty string:
			return false if result.nil?
			
			# Either there was some data available, or we can wait to see if there is data avaialble.
			return !result.empty? || result == :wait_readable
		rescue Errno::ECONNRESET, IOError
			# This might be thrown by recv_nonblock.
			return false
		end
	end
end

require "stringio"

class StringIO
	unless method_defined?(:readable?, false)
		# Check if the StringIO is readable.
		# @returns [Boolean] True if the StringIO is readable (not at EOF).
		def readable?
			!eof?
		end
	end
end

require "openssl"

class OpenSSL::SSL::SSLSocket
	unless method_defined?(:readable?, false)
		# Check if the SSL socket is readable.
		# @returns [Boolean] True if the SSL socket is readable.
		def readable?
			to_io.readable?
		end
	end
end
