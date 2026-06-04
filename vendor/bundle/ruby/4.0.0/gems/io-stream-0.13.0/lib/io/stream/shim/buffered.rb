# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

unless IO.method_defined?(:buffered?, false)
	class IO
		# Check if the IO is buffered.
		# @returns [Boolean] True if the IO is buffered (not synchronized).
		def buffered?
			return !self.sync
		end
		
		# Set the buffered state of the IO.
		# @parameter value [Boolean] True to enable buffering, false to disable.
		def buffered=(value)
			self.sync = !value
		end
	end
end

require "socket"

unless BasicSocket.method_defined?(:buffered?, false)
	# Socket extensions for buffering support.
	class BasicSocket
		# Check if this socket uses TCP protocol.
		# @returns [Boolean] True if the socket is TCP over IPv4 or IPv6.
		def ip_protocol_tcp?
			local_address = self.local_address
			
			return (local_address.afamily == ::Socket::AF_INET || local_address.afamily == ::Socket::AF_INET6) && local_address.socktype == ::Socket::SOCK_STREAM
		end
		
		# Check if the socket is buffered.
		# @returns [Boolean] True if the socket is buffered.
		def buffered?
			return false unless super
			
			if ip_protocol_tcp?
				return !self.getsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY).bool
			else
				return true
			end
		end
		
		# Set the buffered state of the socket.
		# @parameter value [Boolean] True to enable buffering, false to disable.
		def buffered=(value)
			super
			
			if ip_protocol_tcp?
				# When buffered is set to true, TCP_NODELAY shold be disabled.
				self.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, value ? 0 : 1)
			end
		rescue ::Errno::EINVAL
			# On Darwin, sometimes occurs when the connection is not yet fully formed. Empirically, TCP_NODELAY is enabled despite this result.
		rescue ::Errno::EOPNOTSUPP
			# Some platforms may simply not support the operation.
		end
	end
end

require "stringio"

unless StringIO.method_defined?(:buffered?, false)
	# StringIO extensions for buffering support.
	class StringIO
		# Check if the StringIO is buffered.
		# @returns [Boolean] True if the StringIO is buffered (not synchronized).
		def buffered?
			return !self.sync
		end
		
		# Set the buffered state of the StringIO.
		# @parameter value [Boolean] True to enable buffering, false to disable.
		def buffered=(value)
			self.sync = !value
		end
	end
end
