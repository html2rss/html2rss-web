# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# Represents headers that can contain multiple distinct values separated by commas.
			#
			# This isn't a specific header  class is a utility for handling headers with comma-separated values, such as `accept`, `cache-control`, and other similar headers. The values are split and stored as an array internally, and serialized back to a comma-separated string when needed.
			class Trailer < Split
				# Whether this header is acceptable in HTTP trailers.
				# @returns [Boolean] `false`, as Trailer headers control trailer processing and must appear before the message body.
				def self.trailer?
					false
				end
			end
		end
	end
end
