# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

module Protocol
	module HTTP
		module Header
			# Represents headers that can contain multiple distinct values separated by newline characters.
			#
			# This isn't a specific header but is used as a base for headers that store multiple values, such as cookies. The values are split and stored as an array internally, and serialized back to a newline-separated string when needed.
			class Multiple < Array
				# Parses a raw header value.
				#
				# Multiple headers receive each value as a separate header entry, so this method takes a single string value and creates a new instance containing it.
				#
				# @parameter value [String] a single raw header value.
				# @returns [Multiple] a new instance containing the parsed value.
				def self.parse(value)
					self.new([value])
				end
				
				# Coerces a value into a parsed header object.
				#
				# This method is used by the Headers class when setting values via `[]=` to convert application values into the appropriate policy type.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [Multiple] a parsed header object.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:to_s))
					else
						self.parse(value.to_s)
					end
				end
				
				# Initializes the multiple header with the given values.
				#
				# @parameter value [Array | Nil] an array of header values, or `nil` for an empty header.
				def initialize(value = nil)
					super()
					
					if value
						self.concat(value)
					end
				end
				
				# Converts the parsed header value into a raw header value.
				#
				# Multiple headers are transmitted as separate header entries, so this serializes to a newline-separated string for storage.
				#
				# @returns [String] a raw header value (newline-separated string).
				def to_s
					join("\n")
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# This is a base class for headers with multiple values, default is to disallow in trailers.
				# @returns [Boolean] `false`, as most multiple-value headers should not appear in trailers by default.
				def self.trailer?
					false
				end
			end
		end
	end
end
