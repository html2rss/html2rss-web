# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "digest/sha1"
require "securerandom"

module Protocol
	module WebSocket
		# @namespace
		module Headers
			# The protocol string used for the `upgrade:` header (HTTP/1) and `:protocol` pseudo-header (HTTP/2).
			PROTOCOL = "websocket"
			
			# The WebSocket protocol header, used for application level protocol negotiation.
			SEC_WEBSOCKET_PROTOCOL = "sec-websocket-protocol"
			
			# The WebSocket version header. Used for negotiating binary protocol version.
			SEC_WEBSOCKET_VERSION = "sec-websocket-version"
			
			SEC_WEBSOCKET_KEY = "sec-websocket-key"
			SEC_WEBSOCKET_ACCEPT = "sec-websocket-accept"
			
			SEC_WEBSOCKET_EXTENSIONS = "sec-websocket-extensions"
			
			# Provides utilities for generating and verifying the WebSocket handshake nonce.
			module Nounce
				GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
				
				# Valid for the `SEC_WEBSOCKET_KEY` header.
				def self.generate_key
					SecureRandom.base64(16)
				end
				
				# Valid for the `SEC_WEBSOCKET_ACCEPT` header.
				def self.accept_digest(key)
					Digest::SHA1.base64digest(key + GUID)
				end
			end
		end
	end
end
