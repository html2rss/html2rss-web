# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# Represents generic or custom headers that can be used in trailers.
			#
			# This class is used as the default policy for headers not explicitly defined in the POLICY hash.
			#
			# It allows generic headers to be used in HTTP trailers, which is important for:
			# - Custom application headers.
			# - gRPC status headers (grpc-status, grpc-message).
			# - Headers used by proxies and middleware.
			# - Future HTTP extensions.
			class Generic < Split
				# Whether this header is acceptable in HTTP trailers.
				# Generic headers are allowed in trailers by default to support extensibility.
				# @returns [Boolean] `true`, generic headers are allowed in trailers.
				def self.trailer?
					true
				end
			end
		end
	end
end
