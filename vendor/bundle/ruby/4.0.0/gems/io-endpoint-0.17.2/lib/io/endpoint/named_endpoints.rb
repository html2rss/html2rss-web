# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "generic"

module IO::Endpoint
	# A named endpoints collection is a hash of endpoints that can be accessed by name.
	#
	# Unlike {CompositeEndpoint}, which treats endpoints as an ordered list for failover, `NamedEndpoints` allows you to access endpoints by symbolic names, making it useful for scenarios where you need to run the same application on multiple endpoints with different configurations (e.g., HTTP/1 and HTTP/2 on different ports).
	class NamedEndpoints
		# Initialize a new named endpoints collection.
		# @parameter endpoints [Hash(Symbol, Generic)] A hash mapping endpoint names to endpoint instances.
		def initialize(endpoints)
			@endpoints = endpoints
		end
		
		# Get a string representation of the named endpoints.
		# @returns [String] A string representation listing all named endpoints.
		def to_s
			parts = @endpoints.map do |name, endpoint|
				"#{name}:#{endpoint}"
			end
			"named:#{parts.join(",")}"
		end
		
		# Get a detailed string representation of the named endpoints.
		# @returns [String] A detailed string representation including all named endpoints.
		def inspect
			parts = @endpoints.map do |name, endpoint|
				"#{name}: #{endpoint.inspect}"
			end
			"\#<#{self.class} #{parts.join(", ")}>"
		end
		
		# @attribute [Hash(Symbol, Generic)] The endpoints hash mapping names to endpoint instances.
		attr :endpoints
		
		# Access an endpoint by its name.
		# @parameter key [Symbol] The name of the endpoint to access.
		# @returns [Generic, nil] The endpoint with the given name, or nil if not found.
		def [] key
			@endpoints[key]
		end
		
		# Enumerate all endpoints with their names.
		# @yields {|name, endpoint| ...} For each endpoint, yields the name and endpoint.
		# 	@parameter name [Symbol] The name of the endpoint.
		# 	@parameter endpoint [Generic] The endpoint.
		def each(&block)
			@endpoints.each(&block)
		end
		
		# Create a new named endpoints instance with all endpoints bound.
		# @parameter options [Hash] Options to pass to each endpoint's bound method.
		# @returns [NamedEndpoints] A new instance with bound endpoints.
		def bound(**options)
			self.class.new(
				@endpoints.transform_values{|endpoint| endpoint.bound(**options)}
			)
		end
		
		# Create a new named endpoints instance with all endpoints connected.
		# @parameter options [Hash] Options to pass to each endpoint's connected method.
		# @returns [NamedEndpoints] A new instance with connected endpoints.
		def connected(**options)
			self.class.new(
				@endpoints.transform_values{|endpoint| endpoint.connected(**options)}
			)
		end
		
		# Close all endpoints in the collection.
		# Calls `close` on each endpoint value.
		# @returns [void]
		def close
			@endpoints.each_value(&:close)
		end
	end
	
	# Create a named endpoints collection from keyword arguments.
	# @parameter endpoints [Hash(Symbol, Generic)] Named endpoints as keyword arguments.
	# @returns [NamedEndpoints] A new named endpoints instance.
	# @example Create a named endpoints collection
	# 	endpoints = IO::Endpoint.named(
	# 		http1: IO::Endpoint.tcp("localhost", 8080),
	# 		http2: IO::Endpoint.tcp("localhost", 8090)
	# 	)
	def self.named(**endpoints)
		NamedEndpoints.new(endpoints)
	end
end
