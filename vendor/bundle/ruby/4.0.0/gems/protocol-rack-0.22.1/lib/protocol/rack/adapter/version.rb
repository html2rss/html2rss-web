# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "rack"

module Protocol
	module Rack
		module Adapter
			# The version of Rack being used. Can be overridden using the PROTOCOL_RACK_ADAPTER_VERSION environment variable.
			VERSION = ENV.fetch("PROTOCOL_RACK_ADAPTER_VERSION", ::Rack.release)
		end
	end
end
