# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

module Protocol
	module HPACK
		class Error < StandardError
		end
		
		class CompressionError < Error
		end
		
		class DecompressionError < Error
		end
	end
end
