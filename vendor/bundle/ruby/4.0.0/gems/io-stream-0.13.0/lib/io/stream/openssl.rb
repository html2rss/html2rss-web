# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "openssl"

# @namespace
module OpenSSL
	# @namespace
	module SSL
		# SSL socket extensions for stream compatibility.
		class SSLSocket
			unless method_defined?(:buffered?)
				# Check if the SSL socket is buffered.
				# @returns [Boolean] True if the SSL socket is buffered.
				def buffered?
					return to_io.buffered?
				end
			end
			
			unless method_defined?(:buffered=)
				# Set the buffered state of the SSL socket.
				# @parameter value [Boolean] True to enable buffering, false to disable.
				def buffered=(value)
					to_io.buffered = value
				end
			end
		end
	end
end
