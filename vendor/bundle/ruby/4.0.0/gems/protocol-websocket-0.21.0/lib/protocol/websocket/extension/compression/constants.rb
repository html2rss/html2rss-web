# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "zlib"

module Protocol
	module WebSocket
		module Extension
			module Compression
				NAME = "permessage-deflate"
				
				# Zlib is not capable of handling < 9 window bits.
				MINIMUM_WINDOW_BITS = 9
			end
		end
	end
end
