# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# Represents the `priority` header, used to indicate the relative importance of an HTTP request.
			#
			# The `priority` header allows clients to express their preference for how resources should be prioritized by the server. It supports directives like `u=` to specify the urgency level of a request, and `i` to indicate whether a response can be delivered incrementally. The urgency levels range from 0 (highest priority) to 7 (lowest priority), while the `i` directive is a boolean flag.
			class Priority < Split
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value containing comma-separated directives.
				# @returns [Priority] a new instance with normalized (lowercase) directives.
				def self.parse(value)
					self.new(value.downcase.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [Priority] a parsed header object with normalized values.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:downcase))
					else
						self.parse(value.to_s)
					end
				end
				
				# Add a value to the priority header.
				#
				# @parameter value [String] a raw header value containing directives to add to the header.
				def << value
					super(value.downcase)
				end
				
				# The default urgency level if not specified.
				DEFAULT_URGENCY = 3
				
				# The urgency level, if specified using `u=`. 0 is the highest priority, and 7 is the lowest.
				#
				# Note that when duplicate Dictionary keys are encountered, all but the last instance are ignored.
				#
				# @returns [Integer | Nil] the urgency level if specified, or `nil` if not present.
				def urgency(default = DEFAULT_URGENCY)
					if value = self.reverse_find{|value| value.start_with?("u=")}
						_, level = value.split("=", 2)
						return Integer(level)
					end
					
					return default
				end
				
				# Checks if the response should be delivered incrementally.
				#
				# The `i` directive, when present, indicates that the response can be delivered incrementally as data becomes available.
				#
				# @returns [Boolean] whether the request should be delivered incrementally.
				def incremental?
					self.include?("i")
				end
			end
		end
	end
end

