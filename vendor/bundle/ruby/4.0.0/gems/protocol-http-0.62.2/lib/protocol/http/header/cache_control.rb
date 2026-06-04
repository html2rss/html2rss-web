# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# Represents the `cache-control` header, which is a list of cache directives.
			class CacheControl < Split
				# The `private` directive indicates that the response is intended for a single user and must not be stored by shared caches.
				PRIVATE = "private"
				
				# The `public` directive indicates that the response may be stored by any cache, even if it would normally be considered non-cacheable.
				PUBLIC = "public"
				
				# The `no-cache` directive indicates that caches must revalidate the response with the origin server before serving it to clients.
				NO_CACHE = "no-cache"
				
				# The `no-store` directive indicates that caches must not store the response under any circumstances.
				NO_STORE = "no-store"
				
				# The `max-age` directive indicates the maximum amount of time, in seconds, that a response is considered fresh.
				MAX_AGE = "max-age"
				
				# The `s-maxage` directive is similar to `max-age` but applies only to shared caches. If both `s-maxage` and `max-age` are present, `s-maxage` takes precedence in shared caches.
				S_MAXAGE = "s-maxage"
				
				# The `static` directive is a custom directive often used to indicate that the resource is immutable or rarely changes, allowing longer caching periods.
				STATIC = "static"
				
				# The `dynamic` directive is a custom directive used to indicate that the resource is generated dynamically and may change frequently, requiring shorter caching periods.
				DYNAMIC = "dynamic"
				
				# The `streaming` directive is a custom directive used to indicate that the resource is intended for progressive or chunked delivery, such as live video streams.
				STREAMING = "streaming"
				
				# The `must-revalidate` directive indicates that once a response becomes stale, caches must not use it to satisfy subsequent requests without revalidating it with the origin server.
				MUST_REVALIDATE = "must-revalidate"
				
				# The `proxy-revalidate` directive is similar to `must-revalidate` but applies only to shared caches.
				PROXY_REVALIDATE = "proxy-revalidate"
				
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value containing comma-separated directives.
				# @returns [CacheControl] a new instance containing the parsed and normalized directives.
				def self.parse(value)
					self.new(value.downcase.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [CacheControl] a parsed header object with normalized values.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:downcase))
					else
						self.parse(value.to_s)
					end
				end
				
				# Adds a directive to the `cache-control` header. The value will be normalized to lowercase before being added.
				#
				# @parameter value [String] a raw header value containing directives to add.
				def << value
					super(value.downcase)
				end
				
				# @returns [Boolean] whether the `static` directive is present.
				def static?
					self.include?(STATIC)
				end
				
				# @returns [Boolean] whether the `dynamic` directive is present.
				def dynamic?
					self.include?(DYNAMIC)
				end
				
				# @returns [Boolean] whether the `streaming` directive is present.
				def streaming?
					self.include?(STREAMING)
				end
				
				# @returns [Boolean] whether the `private` directive is present.
				def private?
					self.include?(PRIVATE)
				end
				
				# @returns [Boolean] whether the `public` directive is present.
				def public?
					self.include?(PUBLIC)
				end
				
				# @returns [Boolean] whether the `no-cache` directive is present.
				def no_cache?
					self.include?(NO_CACHE)
				end
				
				# @returns [Boolean] whether the `no-store` directive is present.
				def no_store?
					self.include?(NO_STORE)
				end
				
				# @returns [Boolean] whether the `must-revalidate` directive is present.
				def must_revalidate?
					self.include?(MUST_REVALIDATE)
				end
				
				# @returns [Boolean] whether the `proxy-revalidate` directive is present.
				def proxy_revalidate?
					self.include?(PROXY_REVALIDATE)
				end
				
				# @returns [Integer | Nil] the value of the `max-age` directive in seconds, or `nil` if the directive is not present or invalid.
				def max_age
					find_integer_value(MAX_AGE)
				end
				
				# @returns [Integer | Nil] the value of the `s-maxage` directive in seconds, or `nil` if the directive is not present or invalid.
				def s_maxage
					find_integer_value(S_MAXAGE)
				end
				
				private
				
				# Finds and parses an integer value from a directive.
				#
				# @parameter value_name [String] the directive name to search for (e.g., "max-age").
				# @returns [Integer | Nil] the parsed integer value, or `nil` if not found or invalid.
				def find_integer_value(value_name)
					if value = self.find{|value| value.start_with?(value_name)}
						_, age = value.split("=", 2)
						
						if age =~ /\A[0-9]+\z/
							return Integer(age)
						end
					end
				end
			end
		end
	end
end

