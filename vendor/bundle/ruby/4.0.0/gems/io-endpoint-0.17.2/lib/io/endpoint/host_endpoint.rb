# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require_relative "address_endpoint"

module IO::Endpoint
	# Represents an endpoint for a hostname and service that resolves to multiple addresses.
	class HostEndpoint < Generic
		# Initialize a new host endpoint.
		# @parameter specification [Array] The host specification array containing nodename, service, family, socktype, protocol, and flags.
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(specification, **options)
			super(**options)
			
			@specification = specification
		end
		
		# Get a string representation of the host endpoint.
		# @returns [String] A string representation showing hostname and service.
		def to_s
			"host:#{@specification[0]}:#{@specification[1]}"
		end
		
		# Get a detailed string representation of the host endpoint.
		# @returns [String] A detailed string representation including all specification parameters.
		def inspect
			nodename, service, family, socktype, protocol, flags = @specification
			
			"\#<#{self.class} name=#{nodename.inspect} service=#{service.inspect} family=#{family.inspect} type=#{socktype.inspect} protocol=#{protocol.inspect} flags=#{flags.inspect}>"
		end
		
		# @attribute [Array] The host specification array.
		attr :specification
		
		# Get the hostname from the specification.
		# @returns [String, nil] The hostname (nodename) from the specification.
		def hostname
			@specification[0]
		end
		
		# Get the service from the specification.
		# @returns [String, Integer, nil] The service (port) from the specification.
		def service
			@specification[1]
		end
		
		# Try to connect to the given host by connecting to each address in sequence until a connection is made.
		# @yields {|socket| ...} If a block is given, yields the connected socket (may be invoked multiple times during connection attempts).
		# 	@parameter socket [Socket] The socket which is being connected.
		# @returns [Socket] the connected socket
		# @raises [Exception] if no connection could complete successfully
		def connect(wrapper = self.wrapper, &block)
			last_error = nil
			
			Addrinfo.foreach(*@specification) do |address|
				begin
					socket = wrapper.connect(address, **@options)
				rescue => last_error
					Console.debug(self, "Failed to connect:", address, exception: last_error)
					# Try again unless if possible, otherwise raise...
				else
					return socket unless block_given?
					
					begin
						return yield(socket)
					ensure
						socket.close
					end
				end
			end
			
			raise last_error
		end
		
		# Invokes the given block for every address which can be bound to.
		# @yields {|socket| ...} For each address that can be bound, yields the bound socket.
		# 	@parameter socket [Socket] The bound socket.
		# @returns [Array<Socket>] an array of bound sockets
		def bind(wrapper = self.wrapper, &block)
			Addrinfo.foreach(*@specification).map do |address|
				wrapper.bind(address, **@options, &block)
			end
		end
		
		# @yields {|endpoint| ...} For each resolved address, yields an address endpoint.
		# 	@parameter endpoint [AddressEndpoint] An address endpoint.
		def each
			return to_enum unless block_given?
			
			Addrinfo.foreach(*@specification) do |address|
				yield AddressEndpoint.new(address, **@options)
			end
		end
	end
	
	# @parameter arguments nodename, service, family, socktype, protocol, flags. `socktype` will be set to Socket::SOCK_STREAM.
	# @parameter options keyword arguments passed on to {HostEndpoint#initialize}
	#
	# @returns [HostEndpoint]
	def self.tcp(*arguments, **options)
		arguments[3] = ::Socket::SOCK_STREAM
		
		HostEndpoint.new(arguments, **options)
	end
	
	# @parameter arguments nodename, service, family, socktype, protocol, flags. `socktype` will be set to Socket::SOCK_DGRAM.
	# @parameter options keyword arguments passed on to {HostEndpoint#initialize}
	#
	# @returns [HostEndpoint]
	def self.udp(*arguments, **options)
		arguments[3] = ::Socket::SOCK_DGRAM
		
		HostEndpoint.new(arguments, **options)
	end
end
