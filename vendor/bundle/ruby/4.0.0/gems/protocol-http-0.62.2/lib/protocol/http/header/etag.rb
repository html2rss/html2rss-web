# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

module Protocol
	module HTTP
		module Header
			# The `etag` header represents the entity tag for a resource.
			#
			# The `etag` header provides a unique identifier for a specific version of a resource, typically used for cache validation or conditional requests. It can be either a strong or weak validator as defined in RFC 9110.
			class ETag < String
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value.
				# @returns [ETag] a new instance.
				def self.parse(value)
					self.new(value)
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String] the value to coerce.
				# @returns [ETag] a parsed header object.
				def self.coerce(value)
					self.new(value.to_s)
				end
				
				# Replaces the current value of the `etag` header.
				#
				# @parameter value [String] a raw header value for the `etag` header.
				def << value
					replace(value)
				end
				
				# Checks whether the `etag` is a weak validator.
				#
				# Weak validators indicate semantically equivalent content but may not be byte-for-byte identical.
				#
				# @returns [Boolean] whether the `etag` is weak.
				def weak?
					self.start_with?("W/")
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# ETag headers can safely appear in trailers as they provide cache validation metadata.
				# @returns [Boolean] `true`, as ETag headers are metadata that can be computed after response generation.
				def self.trailer?
					true
				end
			end
		end
	end
end
