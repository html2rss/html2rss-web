# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.
# Copyright, 2023, by Emily Love Mills.

require_relative "rack"

module Async
	module WebSocket
		module Adapters
			module Rails
				def self.open(request, **options, &block)
					if response = Rack.open(request.env, **options, &block)
						::Rack::Response[*response]
					else
						::ActionDispatch::Response.new(404)
					end
				end
			end
		end
	end
end
