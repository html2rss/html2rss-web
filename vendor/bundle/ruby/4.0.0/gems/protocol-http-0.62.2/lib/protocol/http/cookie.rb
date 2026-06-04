# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2022, by Herrick Fang.

require_relative "quoted_string"

module Protocol
	module HTTP
		# Represents an individual cookie key-value pair.
		class Cookie
			# Valid cookie name characters according to RFC 6265.
			# cookie-name = token (RFC 2616 defines token)
			VALID_COOKIE_KEY = /\A#{TOKEN}\z/.freeze
			
			# Valid cookie value characters according to RFC 6265.
			# cookie-value = *cookie-octet / ( DQUOTE *cookie-octet DQUOTE )
			# cookie-octet = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
			# Excludes control chars, whitespace, DQUOTE, comma, semicolon, and backslash
			VALID_COOKIE_VALUE = /\A[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]*\z/.freeze
			
			# Initialize the cookie with the given name, value, and directives.
			#
			# @parameter name [String] The name of the cookie, e.g. "session_id".
			# @parameter value [String] The value of the cookie, e.g. "1234".
			# @parameter directives [Hash] The directives of the cookie, e.g. `{"path" => "/"}`.
			# @raises [ArgumentError] If the name or value contains invalid characters.
			def initialize(name, value, directives = nil)
				unless VALID_COOKIE_KEY.match?(name)
					raise ArgumentError, "Invalid cookie name: #{name.inspect}"
				end
				
				if value && !VALID_COOKIE_VALUE.match?(value)
					raise ArgumentError, "Invalid cookie value: #{value.inspect}"
				end
				
				@name = name
				@value = value
				@directives = directives
			end
			
			# @attribute [String] The name of the cookie.
			attr_accessor :name
			
			# @attribute [String] The value of the cookie.
			attr_accessor :value
			
			# @attribute [Hash] The directives of the cookie.
			attr_accessor :directives
			
			# Convert the cookie to a string.
			#
			# @returns [String] The string representation of the cookie.
			def to_s
				buffer = String.new
				
				buffer << @name << "=" << @value
				
				if @directives
					@directives.each do |key, value|
						buffer << ";"
						buffer << key
						
						if value != true
							buffer << "=" << value.to_s
						end
					end
				end
				
				return buffer
			end
			
			# Parse a string into a cookie.
			#
			# @parameter string [String] The string to parse.
			# @returns [Cookie] The parsed cookie.
			def self.parse(string)
				head, *directives = string.split(/\s*;\s*/)
				
				key, value = head.split("=", 2)
				directives = self.parse_directives(directives)
				
				self.new(key, value, directives)
			end
			
			# Parse a list of strings into a hash of directives.
			#
			# @parameter strings [Array(String)] The list of strings to parse.
			# @returns [Hash] The hash of directives.
			def self.parse_directives(strings)
				strings.collect do |string|
					key, value = string.split("=", 2)
					[key, value || true]
				end.to_h
			end
		end
	end
end
