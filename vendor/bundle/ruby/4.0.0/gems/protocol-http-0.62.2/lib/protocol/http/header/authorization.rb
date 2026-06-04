# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2024, by Earlopain.

module Protocol
	module HTTP
		module Header
			# Used for basic authorization.
			#
			# ~~~ ruby
			# headers.add('authorization', Authorization.basic("my_username", "my_password"))
			# ~~~
			#
			# TODO Support other authorization mechanisms, e.g. bearer token.
			class Authorization < String
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value.
				# @returns [Authorization] a new instance.
				def self.parse(value)
					self.new(value)
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String] the value to coerce.
				# @returns [Authorization] a parsed header object.
				def self.coerce(value)
					self.new(value.to_s)
				end
				
				# Splits the header into the credentials.
				#
				# @returns [Tuple(String, String)] The username and password.
				def credentials
					self.split(/\s+/, 2)
				end
				
				# Generate a new basic authorization header, encoding the given username and password.
				#
				# @parameter username [String] The username.
				# @parameter password [String] The password.
				# @returns [Authorization] The basic authorization header.
				def self.basic(username, password)
					strict_base64_encoded = ["#{username}:#{password}"].pack("m0")
					
					self.new(
						"Basic #{strict_base64_encoded}"
					)
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# @returns [Boolean] `false`, as authorization headers are used for request authentication.
				def self.trailer?
					false
				end
			end
		end
	end
end
