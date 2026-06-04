# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "generic"
require_relative "composite_endpoint"
require_relative "socket_endpoint"

require "openssl"

module IO::Endpoint
	# Represents an endpoint that has been connected to a socket.
	class ConnectedEndpoint < Generic
		# Create a connected endpoint from an existing endpoint.
		# @parameter endpoint [Generic] The endpoint to connect.
		# @option close_on_exec [Boolean] Whether to close the socket on exec.
		# @returns [ConnectedEndpoint] A new connected endpoint instance.
		def self.connected(endpoint, close_on_exec: false)
			socket = endpoint.connect
			
			socket.close_on_exec = close_on_exec
			
			return self.new(endpoint, socket, **endpoint.options)
		end
		
		# Initialize a new connected endpoint.
		# @parameter endpoint [Generic] The original endpoint that was connected.
		# @parameter socket [Socket] The socket that was connected.
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(endpoint, socket, **options)
			super(**options)
			
			@endpoint = endpoint
			@socket = socket
		end
		
		# @attribute [Generic] The original endpoint that was connected.
		attr :endpoint
		# @attribute [Socket] The socket that was connected.
		attr :socket
		
		# A endpoint for the local end of the bound socket.
		# @returns [AddressEndpoint] A endpoint for the local end of the connected socket.
		def local_address_endpoint(**options)
			AddressEndpoint.new(socket.to_io.local_address, **options)
		end
		
		# A endpoint for the remote end of the bound socket.
		# @returns [AddressEndpoint] A endpoint for the remote end of the connected socket.
		def remote_address_endpoint(**options)
			AddressEndpoint.new(socket.to_io.remote_address, **options)
		end
		
		# Connect using the already connected socket.
		# @parameter wrapper [Wrapper] The wrapper to use (unused, socket is already connected).
		# @yields {|socket| ...} If a block is given, yields the connected socket.
		# 	@parameter socket [Socket] The connected socket.
		# @returns [Socket] The connected socket or a duplicate if no block is given.
		def connect(wrapper = self.wrapper, &block)
			if block_given?
				yield @socket
			else
				return @socket.dup
			end
		end
		
		# Close the connected socket.
		def close
			if @socket
				@socket.close
				@socket = nil
			end
		end
		
		# Get a string representation of the connected endpoint.
		# @returns [String] A string representation of the connected endpoint.
		def to_s
			"connected:#{@endpoint}"
		end
		
		# Get a detailed string representation of the connected endpoint.
		# @returns [String] A detailed string representation including the socket.
		def inspect
			"\#<#{self.class} #{@socket} connected for #{@endpoint}>"
		end
	end
	
	class Generic
		# Create a connected endpoint from this endpoint.
		# @parameter options [Hash] Options to pass to {ConnectedEndpoint.connected}.
		# @returns [ConnectedEndpoint] A new connected endpoint instance.
		def connected(**options)
			ConnectedEndpoint.connected(self, **options)
		end
	end
end
