# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require_relative "host_endpoint"
require_relative "generic"

require "openssl"

# @namespace
module OpenSSL
	# @namespace
	module SSL
		# Represents an SSL socket with additional methods for compatibility.
		class SSLSocket
			unless method_defined?(:start)
				# Start the SSL handshake (alias for accept).
				def start
					self.accept
				end
			end
		end
		
		# Represents a module that forwards socket methods to the underlying IO object.
		module SocketForwarder
			unless method_defined?(:close_on_exec=)
				# Set whether the socket should be closed on exec.
				# @parameter value [Boolean] Whether to close on exec.
				def close_on_exec=(value)
					to_io.close_on_exec = value
				end
			end
			
			unless method_defined?(:local_address)
				# Get the local address of the socket.
				# @returns [Addrinfo] The local address.
				def local_address
					to_io.local_address
				end
			end
			
			unless method_defined?(:remote_address)
				# Get the remote address of the socket.
				# @returns [Addrinfo] The remote address.
				def remote_address
					to_io.remote_address
				end
			end
			
			unless method_defined?(:wait)
				# Wait for the socket to become ready.
				# @parameter arguments [Array] Arguments to pass to the underlying IO wait method.
				# @returns [IO, nil] The socket if ready, nil otherwise.
				def wait(*arguments)
					to_io.wait(*arguments)
				end
			end
			
			unless method_defined?(:wait_readable)
				# Wait for the socket to become readable.
				# @parameter arguments [Array] Arguments to pass to the underlying IO wait_readable method.
				# @returns [IO, nil] The socket if readable, nil otherwise.
				def wait_readable(*arguments)
					to_io.wait_readable(*arguments)
				end
			end
			
			unless method_defined?(:wait_writable)
				# Wait for the socket to become writable.
				# @parameter arguments [Array] Arguments to pass to the underlying IO wait_writable method.
				# @returns [IO, nil] The socket if writable, nil otherwise.
				def wait_writable(*arguments)
					to_io.wait_writable(*arguments)
				end
			end
			
			if IO.method_defined?(:timeout)
				unless method_defined?(:timeout)
					# Get the timeout for socket operations.
					# @returns [Numeric, nil] The timeout value.
					def timeout
						to_io.timeout
					end
				end
				
				unless method_defined?(:timeout=)
					# Set the timeout for socket operations.
					# @parameter value [Numeric, nil] The timeout value.
					def timeout=(value)
						to_io.timeout = value
					end
				end
			end
		end
	end
end

module IO::Endpoint
	# Represents an SSL/TLS endpoint that wraps another endpoint.
	class SSLEndpoint < Generic
		# Initialize a new SSL endpoint.
		# @parameter endpoint [Generic] The underlying endpoint to wrap with SSL.
		# @option ssl_context [OpenSSL::SSL::SSLContext, nil] An optional SSL context to use.
		# @parameter options [Hash] Additional options including `:ssl_params` and `:hostname`.
		def initialize(endpoint, **options)
			super(**options)
			
			@endpoint = endpoint
			
			if ssl_context = options[:ssl_context]
				@context = build_context(ssl_context)
			else
				@context = nil
			end
		end
		
		# Get a string representation of the SSL endpoint.
		# @returns [String] A string representation showing the underlying endpoint.
		def to_s
			"ssl:#{@endpoint}"
		end
		
		# Get a detailed string representation of the SSL endpoint.
		# @returns [String] A detailed string representation including the underlying endpoint.
		def inspect
			"\#<#{self.class} endpoint=#{@endpoint.inspect}>"
		end
		
		# Get the address from the underlying endpoint.
		# @returns [Address, nil] The address from the underlying endpoint.
		def address
			@endpoint.address
		end
		
		# Get the hostname for SSL verification.
		# @returns [String, nil] The hostname from options or the underlying endpoint.
		def hostname
			@options[:hostname] || @endpoint.hostname
		end
		
		# @attribute [Generic] The underlying endpoint.
		attr :endpoint
		# @attribute [Hash] The options hash.
		attr :options
		
		# Get SSL parameters from options.
		# @returns [Hash, nil] SSL parameters if specified in options.
		def params
			@options[:ssl_params]
		end
		
		# Build an SSL context with configured parameters.
		# @parameter context [OpenSSL::SSL::SSLContext] An optional SSL context to configure.
		# @returns [OpenSSL::SSL::SSLContext] The configured SSL context.
		def build_context(context = ::OpenSSL::SSL::SSLContext.new)
			if params = self.params
				context.set_params(params)
			end
			
			# context.setup
			# context.freeze
			
			return context
		end
		
		# Get or build the SSL context.
		# @returns [OpenSSL::SSL::SSLContext] The SSL context.
		def context
			@context ||= build_context
		end
		
		# Create an SSL server socket from an IO object.
		# @parameter io [IO] The underlying IO object.
		# @returns [OpenSSL::SSL::SSLServer] A new SSL server socket.
		def make_server(io)
			::OpenSSL::SSL::SSLServer.new(io, self.context).tap do |server|
				server.start_immediately = false
			end
		end
		
		# Create an SSL client socket from an IO object.
		# @parameter io [IO] The underlying IO object.
		# @returns [OpenSSL::SSL::SSLSocket] A new SSL client socket.
		def make_socket(io)
			::OpenSSL::SSL::SSLSocket.new(io, self.context).tap do |socket|
				# We consider the underlying IO is owned by the SSL socket:
				socket.sync_close = true
			end
		end
		
		# Connect to the underlying endpoint and establish a SSL connection.
		# @yields {|socket| ...} If a block is given, yields the SSL server socket.
		# 	@parameter socket [Socket] The SSL server socket.
		# @returns [Socket] the connected socket
		def bind(*arguments, **options, &block)
			if block_given?
				@endpoint.bind(*arguments, **options) do |server|
					yield self.make_server(server)
				end
			else
				@endpoint.bind(*arguments, **options).map do |server|
					self.make_server(server)
				end
			end
		end
		
		# Connect to the underlying endpoint and establish a SSL connection.
		# @yields {|socket| ...} If a block is given, yields the connected SSL socket.
		# 	@parameter socket [Socket] The connected SSL socket.
		# @returns [Socket] the connected socket
		def connect(&block)
			socket = self.make_socket(@endpoint.connect)
			
			if hostname = self.hostname
				socket.hostname = hostname
			end
			
			begin
				socket.connect
			rescue
				socket.close
				raise
			end
			
			return socket unless block_given?
			
			begin
				yield socket
			ensure
				socket.close
			end
		end
		
		# Enumerate all endpoints by wrapping each underlying endpoint with SSL.
		# @yields {|endpoint| ...} For each underlying endpoint, yields an SSL-wrapped endpoint.
		# 	@parameter endpoint [SSLEndpoint] An SSL endpoint.
		def each
			return to_enum unless block_given?
			
			@endpoint.each do |endpoint|
				yield self.class.new(endpoint, **@options)
			end
		end
	end
	
	# @parameter arguments
	# @parameter ssl_context [OpenSSL::SSL::SSLContext, nil]
	# @parameter hostname [String, nil]
	# @parameter options keyword arguments passed through to {Endpoint.tcp}
	#
	# @returns [SSLEndpoint]
	def self.ssl(*arguments, ssl_context: nil, hostname: nil, **options)
		SSLEndpoint.new(self.tcp(*arguments, **options), ssl_context: ssl_context, hostname: hostname)
	end
end
