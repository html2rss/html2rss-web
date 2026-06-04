# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require_relative "extension/compression"
require_relative "headers"

module Protocol
	module WebSocket
		# Manages WebSocket extensions negotiated during the handshake.
		module Extensions
			# Parse a list of extension header values into name and argument pairs.
			# @parameter headers [Array(String)] The raw extension header values.
			# @yields {|name, arguments| ...} Each parsed extension.
			# 	@parameter name [String] The name of the extension.
			# 	@parameter arguments [Array] The key-value argument pairs.
			def self.parse(headers)
				return to_enum(:parse, headers) unless block_given?
				
				headers.each do |header|
					name, *arguments = header.split(/\s*;\s*/)
					
					arguments = arguments.map do |argument|
						argument.split("=", 2)
					end
					
					yield name, arguments
				end
			end
			
			# Manages extensions on the client side, offering and accepting server responses.
			class Client
				# Create a default client with permessage-deflate compression enabled.
				# @returns [Client] A new client with the default compression extension.
				def self.default
					self.new([
						[Extension::Compression, {}]
					])
				end
				
				# Initialize a new client extension manager.
				# @parameter extensions [Array] The list of extensions to offer, each as `[klass, options]`.
				def initialize(extensions = [])
					@extensions = extensions
					@accepted = []
				end
				
				# @attribute [Array] The list of extensions to offer.
				attr :extensions
				# @attribute [Array] The extensions accepted after negotiation.
				attr :accepted
				
				# Build a lookup table of extensions keyed by their name.
				# @returns [Hash] A hash mapping extension names to their `[klass, options]` pairs.
				def named
					@extensions.map do |extension|
						[extension.first::NAME, extension]
					end.to_h
				end
				
				# Yield extension offer headers for each registered extension.
				# @yields {|header| ...} Each offer header string.
				# 	@parameter header [Array(String)] The extension offer header tokens.
				def offer
					@extensions.each do |extension, options|
						if header = extension.offer(**options)
							yield header
						end
					end
				end
				
				# Accept server extension responses and record the negotiated extensions.
				# @parameter headers [Array(String)] The `Sec-WebSocket-Extensions` response header values.
				# @returns [Array] The accepted extensions as `[klass, options]` pairs.
				def accept(headers)
					named = self.named
					
					# Each response header should map to at least one extension.
					Extensions.parse(headers) do |name, arguments|
						if extension = named.delete(name)
							klass, options = extension
							
							options = klass.accept(arguments, **options)
							
							@accepted << [klass, options]
						end
					end
					
					return @accepted
				end
				
				# Apply all accepted extensions to the given connection as a client.
				# @parameter connection [Connection] The WebSocket connection to configure.
				def apply(connection)
					@accepted.each do |(klass, options)|
						klass.client(connection, **options)
					end
				end
			end
			
			# Manages extensions on the server side, negotiating client offers and applying the agreed extensions.
			class Server
				# Create a default server with permessage-deflate compression enabled.
				# @returns [Server] A new server with the default compression extension.
				def self.default
					self.new([
						[Extension::Compression, {}]
					])
				end
				
				# Initialize a new server extension manager.
				# @parameter extensions [Array] The list of supported extensions, each as `[klass, options]`.
				def initialize(extensions)
					@extensions = extensions
					@accepted = []
				end
				
				# @attribute [Array] The list of supported extensions.
				attr :extensions
				# @attribute [Array] The extensions accepted after negotiation.
				attr :accepted
				
				# Build a lookup table of extensions keyed by their name.
				# @returns [Hash] A hash mapping extension names to their `[klass, options]` pairs.
				def named
					@extensions.map do |extension|
						[extension.first::NAME, extension]
					end.to_h
				end
				
				# Negotiate client extension offers and yield accepted response headers.
				# @parameter headers [Array(String)] The `Sec-WebSocket-Extensions` request header values.
				# @yields {|header| ...} Each accepted extension header to include in the response.
				# 	@parameter header [Array(String)] The negotiated extension header tokens.
				# @returns [Array] The accepted extensions as `[klass, options]` pairs.
				def accept(headers)
					extensions = []
					
					named = self.named
					response = []
					
					# Each response header should map to at least one extension.
					Extensions.parse(headers) do |name, arguments|
						if extension = named[name]
							klass, options = extension
							
							if result = klass.negotiate(arguments, **options)
								header, options = result
								
								# The extension is accepted and no further offers will be considered:
								named.delete(name)
								
								yield header if block_given?
								
								@accepted << [klass, options]
							end
						end
					end
					
					return @accepted
				end
				
				# Apply all accepted extensions to the given connection as a server.
				# @parameter connection [Connection] The WebSocket connection to configure.
				def apply(connection)
					@accepted.reverse_each do |(klass, options)|
						klass.server(connection, **options)
					end
				end
			end
		end
	end
end
