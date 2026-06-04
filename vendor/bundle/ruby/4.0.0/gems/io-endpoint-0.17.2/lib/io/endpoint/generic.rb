# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

# require_relative 'address'
require "uri"
require "socket"

module IO::Endpoint
	Address = Addrinfo
	
	# Endpoints represent a way of connecting or binding to an address.
	class Generic
		# Initialize a new generic endpoint.
		# @parameter options [Hash] Configuration options for the endpoint.
		def initialize(**options)
			@options = options.freeze
		end
		
		# Create a new endpoint with merged options.
		# @parameter options [Hash] Additional options to merge with existing options.
		# @returns [Generic] A new endpoint instance with merged options.
		def with(**options)
			dup = self.dup
			
			dup.options = @options.merge(options)
			
			return dup
		end
		
		attr_accessor :options
		
		# @returns [String] The hostname of the bound socket.
		def hostname
			@options[:hostname]
		end
		
		# If `SO_REUSEPORT` is enabled on a socket, the socket can be successfully bound even if there are existing sockets bound to the same address, as long as all prior bound sockets also had `SO_REUSEPORT` set before they were bound.
		# @returns [Boolean, nil] The value for `SO_REUSEPORT`.
		def reuse_port?
			@options[:reuse_port]
		end
		
		# If `SO_REUSEADDR` is enabled on a socket prior to binding it, the socket can be successfully bound unless there is a conflict with another socket bound to exactly the same combination of source address and port. Additionally, when set, binding a socket to the address of an existing socket in `TIME_WAIT` is not an error.
		# @returns [Boolean] The value for `SO_REUSEADDR`.
		def reuse_address?
			@options[:reuse_address]
		end
		
		# Controls SO_LINGER. The amount of time the socket will stay in the `TIME_WAIT` state after being closed.
		# @returns [Integer, nil] The value for SO_LINGER.
		def linger
			@options[:linger]
		end
		
		# @returns [Numeric] The default timeout for socket operations.
		def timeout
			@options[:timeout]
		end
		
		# @returns [Address] the address to bind to before connecting.
		def local_address
			@options[:local_address]
		end
		
		# Bind a socket to the given address. If a block is given, the socket will be automatically closed when the block exits.
		# @parameter wrapper [Wrapper] The wrapper to use for binding.
		# @yields {|socket| ...} If a block is given, yields the bound socket.
		# 	@parameter socket [Socket] The socket which has been bound.
		# @returns [Array(Socket)] the bound socket
		def bind(wrapper = self.wrapper, &block)
			raise NotImplementedError
		end
		
		# Connects a socket to the given address. If a block is given, the socket will be automatically closed when the block exits.
		# @parameter wrapper [Wrapper] The wrapper to use for connecting.
		# @returns [Socket] the connected socket
		def connect(wrapper = self.wrapper, &block)
			raise NotImplementedError
		end
		
		# Bind and accept connections on the given address.
		# @parameter wrapper [Wrapper] The wrapper to use for accepting connections.
		# @yields {|socket| ...} For each accepted connection, yields the socket.
		# 	@parameter socket [Socket] The accepted socket.
		def accept(wrapper = self.wrapper, &block)
			bind(wrapper) do |server|
				wrapper.accept(server, **@options, &block)
			end
		end
		
		# Enumerate all discrete paths as endpoints.
		# @yields {|endpoint| ...} For each endpoint, yields it.
		# 	@parameter endpoint [Endpoint] The endpoint.
		def each
			return to_enum unless block_given?
			
			yield self
		end
		
		# Create an Endpoint instance by URI scheme. The host and port of the URI will be passed to the Endpoint factory method, along with any options.
		#
		# You should not use untrusted input as it may execute arbitrary code.
		#
		# @parameter string [String] URI as string. Scheme will decide implementation used.
		# @parameter options keyword arguments passed through to {#initialize}
		#
		# @see Endpoint.ssl ssl - invoked when parsing a URL with the ssl scheme "ssl://127.0.0.1"
		# @see Endpoint.tcp tcp - invoked when parsing a URL with the tcp scheme: "tcp://127.0.0.1"
		# @see Endpoint.udp udp - invoked when parsing a URL with the udp scheme: "udp://127.0.0.1"
		# @see Endpoint.unix unix - invoked when parsing a URL with the unix scheme: "unix://127.0.0.1"
		def self.parse(string, **options)
			uri = URI.parse(string)
			
			IO::Endpoint.public_send(uri.scheme, uri.host, uri.port, **options)
		end
		
		# The default wrapper to use for binding, connecting, and accepting connections.
		def wrapper
			@options[:wrapper] || Wrapper.default
		end
	end
end
