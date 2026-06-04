# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require "time"

module Protocol
	module HTTP
		module Header
			# The `date` header represents the date and time at which the message was originated.
			#
			# This header is typically included in HTTP responses and follows the format defined in RFC 9110.
			class Date < String
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value.
				# @returns [Date] a new instance.
				def self.parse(value)
					self.new(value)
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String] the value to coerce.
				# @returns [Date] a parsed header object.
				def self.coerce(value)
					self.new(value.to_s)
				end
				
				# Replaces the current value of the `date` header.
				#
				# @parameter value [String] a raw header value for the `date` header.
				def << value
					replace(value)
				end
				
				# Converts the `date` header value to a `Time` object.
				#
				# @returns [Time] the parsed time object corresponding to the `date` header value.
				def to_time
					::Time.parse(self)
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# Date headers can safely appear in trailers as they provide metadata about response generation.
				# @returns [Boolean] `true`, as date headers are metadata that can be computed after response generation.
				def self.trailer?
					true
				end
			end
		end
	end
end
