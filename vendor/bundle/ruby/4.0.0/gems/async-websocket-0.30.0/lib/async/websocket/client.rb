# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2024, by Samuel Williams.
# Copyright, 2019, by Bryan Powell.
# Copyright, 2019, by Janko Marohnić.
# Copyright, 2023, by Thomas Morgan.

require_relative "request"
require_relative "connection"

require "protocol/websocket/headers"
require "protocol/websocket/extensions"
require "protocol/http/middleware"

require "async/http/client"

require "delegate"

module Async
	module WebSocket
		# This is a basic synchronous websocket client:
		class Client < ::Protocol::HTTP::Middleware
			include ::Protocol::WebSocket::Headers
			
			# @return [Client] a client which can be used to establish websocket connections to the given endpoint.
			def self.open(endpoint, **options, &block)
				client = self.new(HTTP::Client.new(endpoint, **options), mask: true)
				
				return client unless block_given?
				
				begin
					yield client
				ensure
					client.close
				end
			end
			
			class ClientCloseDecorator < SimpleDelegator
				def initialize(client, connection)
					@client = client
					super(connection)
				end
				
				def close(...)
					super(...)
					
					if @client
						@client.close
						@client = nil
					end
				end
			end
			
			# @return [Connection] an open websocket connection to the given endpoint.
			def self.connect(endpoint, *arguments, **options, &block)
				Sync do
					client = self.open(endpoint, *arguments)
					connection = client.connect(endpoint.authority, endpoint.path, **options)
					
					return ClientCloseDecorator.new(client, connection) unless block_given?
					
					begin
						yield connection
						
					ensure
						connection&.close
						client&.close
					end
				end
			end
			
			def initialize(client, **options)
				super(client)
				
				@options = options
			end
			
			class Framer < ::Protocol::WebSocket::Framer
				def initialize(pool, connection, stream)
					super(stream)
					@pool = pool
					@connection = connection
				end
				
				attr :connection
				
				def close
					super
					
					if @pool
						@pool.release(@connection)
						@pool = nil
						@connection = nil
					end
				end
			end
			
			def connect(authority, path, scheme: @delegate.scheme, headers: nil, handler: Connection, extensions: ::Protocol::WebSocket::Extensions::Client.default, **options, &block)
				headers = ::Protocol::HTTP::Headers[headers]
				
				extensions&.offer do |extension|
					headers.add(SEC_WEBSOCKET_EXTENSIONS, extension.join("; "))
				end
				
				request = Request.new(scheme, authority, path, headers, **options)
				
				pool = @delegate.pool
				connection = pool.acquire
				
				response = request.call(connection)
				
				unless response.stream?
					raise ConnectionError.new("Failed to negotiate connection!", response.unwrap)
				end
				
				protocol = response.headers[SEC_WEBSOCKET_PROTOCOL]&.first
				stream = response.stream
				
				framer = Framer.new(pool, connection, stream)
				
				connection = nil
				
				if extension_headers = response.headers[SEC_WEBSOCKET_EXTENSIONS]
					extensions.accept(extension_headers)
				end
				
				response = nil
				stream = nil
				
				return handler.call(framer, protocol, extensions, **@options, &block)
			ensure
				pool.release(connection) if connection
			end
		end
	end
end
