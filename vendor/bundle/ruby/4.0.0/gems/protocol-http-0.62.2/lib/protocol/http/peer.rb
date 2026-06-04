# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

module Protocol
	module HTTP
		# Provide a well defined, cached representation of a peer (address).
		class Peer
			# Create a new peer object for the given IO object, using the remote address if available.
			#
			# @returns [Peer | Nil] The peer object, or nil if the remote address is not available.
			def self.for(io)
				if address = io.remote_address
					return new(address)
				end
			end
			
			# Initialize the peer with the given address.
			#
			# @parameter address [Addrinfo] The remote address of the peer.
			def initialize(address)
				@address = address
				
				if address.ip?
					@ip_address = @address.ip_address
				end
			end
			
			# @attribute [Addrinfo] The remote address of the peer.
			attr :address
			
			# @attribute [String] The IP address of the peer, if available.
			attr :ip_address
			
			alias remote_address address
		end
	end
end
