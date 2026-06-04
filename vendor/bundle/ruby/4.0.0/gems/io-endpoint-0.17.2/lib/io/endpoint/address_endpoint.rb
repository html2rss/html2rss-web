# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require "socket"

require_relative "generic"
require_relative "wrapper"

module IO::Endpoint
	# Represents an endpoint for a specific network address.
	class AddressEndpoint < Generic
		# Initialize a new address endpoint.
		# @parameter address [Address] The network address for this endpoint.
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(address, **options)
			super(**options)
			
			@address = address
		end
		
		# Get a string representation of the endpoint.
		# @returns [String] A string representation of the endpoint address.
		def to_s
			case @address.afamily
			when Socket::AF_INET
				"inet:#{@address.inspect_sockaddr}"
			when Socket::AF_INET6
				"inet6:#{@address.inspect_sockaddr}"
			when Socket::AF_UNIX
				"unix:#{@address.unix_path}"
			else
				"address:#{@address.inspect_sockaddr}"
			end
		end
		
		# Get a detailed string representation of the endpoint.
		# @returns [String] A detailed string representation including the address.
		def inspect
			"\#<#{self.class} address=#{@address.inspect}>"
		end
		
		# @attribute [Address] The network address for this endpoint.
		attr :address
		
		# Bind a socket to the given address. If a block is given, the socket will be automatically closed when the block exits.
		# @yields {|socket| ...} If a block is given, yields the bound socket.
		# 	@parameter socket [Socket] The socket which has been bound.
		# @returns [Array(Socket)] the bound socket
		def bind(wrapper = self.wrapper, &block)
			[wrapper.bind(@address, **@options, &block)]
		end
		
		# Connects a socket to the given address. If a block is given, the socket will be automatically closed when the block exits.
		# @returns [Socket] the connected socket
		def connect(wrapper = self.wrapper, &block)
			wrapper.connect(@address, **@options, &block)
		end
	end
end
