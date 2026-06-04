# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require_relative "generic"

module IO::Endpoint
	# A composite endpoint is a collection of endpoints that are used in order.
	class CompositeEndpoint < Generic
		# Initialize a new composite endpoint.
		# @parameter endpoints [Array(Generic)] The endpoints to compose.
		# @parameter options [Hash] Additional options to pass to the parent class and propagate to endpoints.
		def initialize(endpoints, **options)
			super(**options)
			
			# If any options were provided, propagate them to the endpoints:
			if options.any?
				endpoints = endpoints.map{|endpoint| endpoint.with(**options)}
			end
			
			@endpoints = endpoints
		end
		
		# Get a string representation of the composite endpoint.
		# @returns [String] A string representation listing all endpoints.
		def to_s
			"composite:#{@endpoints.join(",")}"
		end
		
		# Get a detailed string representation of the composite endpoint.
		# @returns [String] A detailed string representation including all endpoints.
		def inspect
			"\#<#{self.class} endpoints=#{@endpoints}>"
		end
		
		# Create a new composite endpoint with merged options.
		# @parameter options [Hash] Additional options to merge with existing options.
		# @returns [CompositeEndpoint] A new composite endpoint instance with merged options.
		def with(**options)
			self.class.new(endpoints.map{|endpoint| endpoint.with(**options)}, **@options.merge(options))
		end
		
		# @attribute [Array(Generic)] The endpoints in this composite endpoint.
		attr :endpoints
		
		# The number of endpoints in the composite endpoint.
		def size
			@endpoints.size
		end
		
		# Enumerate all endpoints in the composite endpoint.
		# @yields {|endpoint| ...} For each endpoint in the composite, yields it.
		# 	@parameter endpoint [Generic] An endpoint in the composite.
		def each(&block)
			@endpoints.each do |endpoint|
				endpoint.each(&block)
			end
		end
		
		# Connect to the first endpoint that succeeds.
		# @parameter wrapper [Wrapper] The wrapper to use for connecting.
		# @yields {|socket| ...} If a block is given, yields the connected socket from the first successful endpoint.
		# 	@parameter socket [Socket] The connected socket.
		# @returns [Socket] The connected socket.
		# @raises [Exception] If all endpoints fail to connect, raises the last error encountered.
		def connect(wrapper = self.wrapper, &block)
			last_error = nil
			
			@endpoints.each do |endpoint|
				begin
					return endpoint.connect(wrapper, &block)
				rescue => last_error
				end
			end
			
			raise last_error
		end
		
		# Bind all endpoints in the composite.
		# @parameter wrapper [Wrapper] The wrapper to use for binding.
		# @yields {|socket| ...} For each endpoint that is bound, yields the bound socket.
		# 	@parameter socket [Socket] A bound socket.
		# @returns [Array(Socket)] An array of bound sockets if no block is given.
		def bind(wrapper = self.wrapper, &block)
			if block_given?
				@endpoints.each do |endpoint|
					endpoint.bind(&block)
				end
			else
				@endpoints.map(&:bind).flatten.compact
			end
		end
	end
	
	# Create a composite endpoint from multiple endpoints.
	# @parameter endpoints [Array(Generic)] The endpoints to compose.
	# @parameter options [Hash] Additional options to pass to the composite endpoint.
	# @returns [CompositeEndpoint] A new composite endpoint instance.
	def self.composite(*endpoints, **options)
		CompositeEndpoint.new(endpoints, **options)
	end
end
