# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.
# Copyright, 2024, by Ryu Sato.

require "protocol/http/middleware"
require "protocol/http/request"

require "protocol/http/headers"
require "protocol/websocket/headers"

require_relative "error"

module Async
	module WebSocket
		# This is required for HTTP/1.x to upgrade the connection to the WebSocket protocol.
		# See https://tools.ietf.org/html/rfc6455
		class UpgradeRequest < ::Protocol::HTTP::Request
			include ::Protocol::WebSocket::Headers
			
			class Wrapper
				def initialize(response, verified:)
					@response = response
					@stream = nil
					@verified = verified
				end
				
				def close
					@response.close
				end
				
				def unwrap
					@response.buffered!
				end
				
				attr_accessor :response
				
				def stream?
					@response.status == 101 && @verified
				end
				
				def status
					@response.status
				end
				
				def headers
					@response.headers
				end
				
				def stream
					@stream ||= @response.hijack!
				end
			end
			
			def initialize(request, protocols: [], version: 13, &block)
				@key = Nounce.generate_key
				
				headers = ::Protocol::HTTP::Headers[request.headers]
				
				headers.add(SEC_WEBSOCKET_KEY, @key)
				headers.add(SEC_WEBSOCKET_VERSION, String(version))
				
				if protocols.any?
					headers.add(SEC_WEBSOCKET_PROTOCOL, protocols.join(","))
				end
				
				super(request.scheme, request.authority, ::Protocol::HTTP::Methods::GET, request.path, nil, headers, nil, PROTOCOL)
			end
			
			def call(connection)
				response = super
				
				if accept_digest = response.headers[SEC_WEBSOCKET_ACCEPT]&.first
					expected_accept_digest = Nounce.accept_digest(@key)
					
					unless accept_digest and accept_digest == expected_accept_digest
						raise ProtocolError, "Invalid accept digest, expected #{expected_accept_digest.inspect}, got #{accept_digest.inspect}!"
					end
				end
				
				verified = accept_digest && Array(response.protocol).map(&:downcase) == %w(websocket) && response.headers["connection"]&.include?("upgrade")
				
				return Wrapper.new(response, verified: verified)
			end
		end
	end
end
