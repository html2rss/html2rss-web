# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require_relative "generic"

module IO::Endpoint
	# This class doesn't exert ownership over the specified socket, wraps a native ::IO.
	class SocketEndpoint < Generic
		# Initialize a new socket endpoint.
		# @parameter socket [Socket] The socket to wrap.
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(socket, **options)
			super(**options)
			
			@socket = socket
		end
		
		# Get a string representation of the socket endpoint.
		# @returns [String] A string representation showing the socket.
		def to_s
			"socket:#{@socket}"
		end
		
		# Get a detailed string representation of the socket endpoint.
		# @returns [String] A detailed string representation including the socket.
		def inspect
			"\#<#{self.class} #{@socket.inspect}>"
		end
		
		# @attribute [Socket] The wrapped socket.
		attr :socket
		
		# Bind using the wrapped socket.
		# @yields {|socket| ...} If a block is given, yields the socket.
		# 	@parameter socket [Socket] The socket.
		# @returns [Socket] The socket.
		def bind(&block)
			if block_given?
				yield @socket
			else
				return @socket
			end
		end
		
		# Connect using the wrapped socket.
		# @yields {|socket| ...} If a block is given, yields the socket.
		# 	@parameter socket [Socket] The socket.
		# @returns [Socket] The socket.
		def connect(&block)
			if block_given?
				yield @socket
			else
				return @socket
			end
		end
	end
	
	# Create a socket endpoint from an existing socket.
	# @parameter socket [Socket] The socket to wrap.
	# @parameter options [Hash] Additional options to pass to the socket endpoint.
	# @returns [SocketEndpoint] A new socket endpoint instance.
	def self.socket(socket, **options)
		SocketEndpoint.new(socket, **options)
	end
end
