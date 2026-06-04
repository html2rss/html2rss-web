# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "http"
require "protocol/rack/request"
require "protocol/rack/adapter"

module Async
	module WebSocket
		module Adapters
			module Rack
				include ::Protocol::WebSocket::Headers
				
				def self.websocket?(env)
					HTTP.websocket?(
						::Protocol::Rack::Request[env]
					)
				end
				
				def self.open(env, **options, &block)
					request = ::Protocol::Rack::Request[env]
					
					if response = HTTP.open(request, **options, &block)
						return Protocol::Rack::Adapter.make_response(env, response)
					end
				end
			end
		end
	end
end
