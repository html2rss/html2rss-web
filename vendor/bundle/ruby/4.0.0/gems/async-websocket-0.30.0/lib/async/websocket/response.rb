# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "upgrade_response"
require_relative "connect_response"

require_relative "error"

module Async
	module WebSocket
		module Response
			# Send the request to the given connection.
			def self.for(request, headers = nil, **options, &body)
				if request.version =~ /http\/1/i
					return UpgradeResponse.new(request, headers, **options, &body)
				elsif request.version =~ /http\/2/i
					return ConnectResponse.new(request, headers, **options, &body)
				end
				
				raise UnsupportedVersionError, "Unsupported HTTP version: #{request.version}!"
			end
		end
	end
end
