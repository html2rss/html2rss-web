# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# Represents the `vary` header, which specifies the request headers a server considers when determining the response.
			#
			# The `vary` header is used in HTTP responses to indicate which request headers affect the selected response. It allows caches to differentiate stored responses based on specific request headers.
			class Vary < Split
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value containing comma-separated header names.
				# @returns [Vary] a new instance with normalized (lowercase) header names.
				def self.parse(value)
					self.new(value.downcase.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [Vary] a parsed header object with normalized values.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:downcase))
					else
						self.parse(value.to_s)
					end
				end
				
				# Adds one or more comma-separated values to the `vary` header. The values are converted to lowercase for normalization.
				#
				# @parameter value [String] a raw header value containing one or more values separated by commas.
				def << value
					super(value.downcase)
				end
			end
		end
	end
end

