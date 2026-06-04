# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "coder/json"

module Protocol
	module WebSocket
		# @namespace
		module Coder
			# The default coder for WebSocket messages.
			DEFAULT = JSON::DEFAULT
		end
	end
end
