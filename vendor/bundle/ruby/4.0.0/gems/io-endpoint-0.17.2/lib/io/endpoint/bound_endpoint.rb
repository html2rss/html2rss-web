# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "generic"
require_relative "composite_endpoint"
require_relative "address_endpoint"

module IO::Endpoint
	# Represents an endpoint that has been bound to one or more sockets.
	class BoundEndpoint < Generic
		# Create a bound endpoint from an existing endpoint.
		# @parameter endpoint [Generic] The endpoint to bind.
		# @option backlog [Integer] The maximum length of the queue of pending connections.
		# @option close_on_exec [Boolean] Whether to close sockets on exec.
		# @returns [BoundEndpoint] A new bound endpoint instance.
		def self.bound(endpoint, backlog: Socket::SOMAXCONN, close_on_exec: false)
			sockets = endpoint.bind
			
			sockets.each do |socket|
				socket.close_on_exec = close_on_exec
			end
			
			return self.new(endpoint, sockets, **endpoint.options)
		end
		
		# Initialize a new bound endpoint.
		# @parameter endpoint [Generic] The original endpoint that was bound.
		# @parameter sockets [Array(Socket)] The sockets that were bound.
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(endpoint, sockets, **options)
			super(**options)
			
			@endpoint = endpoint
			@sockets = sockets
		end
		
		# @attribute [Generic] The original endpoint that was bound.
		attr :endpoint
		# @attribute [Array(Socket)] The sockets that were bound.
		attr :sockets
		
		# A endpoint for the local end of the bound socket.
		# @returns [CompositeEndpoint] A composite endpoint for the local end of the bound socket.
		def local_address_endpoint(**options)
			endpoints = @sockets.map do |socket|
				AddressEndpoint.new(socket.to_io.local_address, **options)
			end
			
			return CompositeEndpoint.new(endpoints)
		end
		
		# A endpoint for the remote end of the bound socket.
		# @returns [CompositeEndpoint] A composite endpoint for the remote end of the bound socket.
		def remote_address_endpoint(**options)
			endpoints = @sockets.map do |wrapper|
				AddressEndpoint.new(socket.to_io.remote_address, **options)
			end
			
			return CompositeEndpoint.new(endpoints)
		end
		
		# Close all bound sockets.
		def close
			@sockets.each(&:close)
			@sockets.clear
		end
		
		# Get a string representation of the bound endpoint.
		# @returns [String] A string representation of the bound endpoint.
		def to_s
			"bound:#{@endpoint}"
		end
		
		# Get a detailed string representation of the bound endpoint.
		# @returns [String] A detailed string representation including socket count.
		def inspect
			"\#<#{self.class} #{@sockets.size} bound sockets for #{@endpoint}>"
		end
		
		# Bind the endpoint using the given wrapper.
		# @parameter wrapper [Wrapper] The wrapper to use for binding.
		# @yields {|socket| ...} If a block is given, yields each bound socket.
		# 	@parameter socket [Socket] A bound socket.
		# @returns [Array(Socket)] An array of bound sockets.
		def bind(wrapper = self.wrapper, &block)
			@sockets.map do |server|
				if block_given?
					wrapper.schedule do
						yield server
					end
				else
					server.dup
				end
			end
		end
	end
	
	class Generic
		# Create a bound endpoint from this endpoint.
		# @parameter options [Hash] Options to pass to {BoundEndpoint.bound}.
		# @returns [BoundEndpoint] A new bound endpoint instance.
		def bound(**options)
			BoundEndpoint.bound(self, **options)
		end
	end
end
