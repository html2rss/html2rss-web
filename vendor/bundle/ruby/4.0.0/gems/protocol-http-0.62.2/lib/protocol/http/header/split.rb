# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

module Protocol
	module HTTP
		module Header
			# Represents headers that can contain multiple distinct values separated by commas.
			#
			# This isn't a specific header  class is a utility for handling headers with comma-separated values, such as `accept`, `cache-control`, and other similar headers. The values are split and stored as an array internally, and serialized back to a comma-separated string when needed.
			class Split < Array
				# Regular expression used to split values on commas, with optional surrounding whitespace.
				COMMA = /\s*,\s*/
				
				# Parses a raw header value.
				#
				# Split headers receive comma-separated values in a single header entry. This method splits the raw value into individual entries.
				#
				# @parameter value [String] a raw header value containing multiple entries separated by commas.
				# @returns [Split] a new instance containing the parsed values.
				def self.parse(value)
					self.new(value.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# This method is used by the Headers class when setting values via `[]=` to convert application values into the appropriate policy type.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [Split] a parsed header object.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:to_s))
					else
						self.parse(value.to_s)
					end
				end
				
				# Initializes a `Split` header with the given values.
				#
				# @parameter value [Array | String | Nil] an array of values, a raw header value, or `nil` for an empty header.
				def initialize(value = nil)
					if value.is_a?(Array)
						super(value)
					elsif value.is_a?(String)
						# Compatibility with the old constructor, prefer to use `parse` instead:
						super()
						self << value
					elsif value
						raise ArgumentError, "Invalid value: #{value.inspect}"
					end
				end
				
				# Adds one or more comma-separated values to the header.
				#
				# The input string is split into distinct entries and appended to the array.
				#
				# @parameter value [String] a raw header value containing one or more values separated by commas.
				def << value
					self.concat(value.split(COMMA))
				end
				
				# Converts the parsed header value into a raw header value.
				#
				# @returns [String] a raw header value (comma-separated string).
				def to_s
					join(",")
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# This is a base class for comma-separated headers, default is to disallow in trailers.
				# @returns [Boolean] `false`, as most comma-separated headers should not appear in trailers by default.
				def self.trailer?
					false
				end
				
			protected
				
				def reverse_find(&block)
					reverse_each do |value|
						return value if block.call(value)
					end
					
					return nil
				end
			end
		end
	end
end
