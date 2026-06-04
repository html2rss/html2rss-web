# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "split"
require_relative "../quoted_string"
require_relative "../error"

module Protocol
	module HTTP
		module Header
			# The `accept-language` header represents a list of languages that the client can accept.
			class AcceptLanguage < Split
				ParseError = Class.new(Error)
				
				# https://tools.ietf.org/html/rfc3066#section-2.1
				NAME = /\*|[A-Z]{1,8}(-[A-Z0-9]{1,8})*/i
				
				# https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.9
				QVALUE = /0(\.[0-9]{0,6})?|1(\.[0]{0,6})?/
				
				# https://greenbytes.de/tech/webdav/rfc7231.html#quality.values
				LANGUAGE = /\A(?<name>#{NAME})(\s*;\s*q=(?<q>#{QVALUE}))?\z/
				
				Language = Struct.new(:name, :q) do
					def quality_factor
						(q || 1.0).to_f
					end
					
					def <=> other
						other.quality_factor <=> self.quality_factor
					end
				end
				
				# Parse the `accept-language` header value into a list of languages.
				#
				# @returns [Array(Charset)] the list of character sets and their associated quality factors.
				def languages
					self.map do |value|
						if match = value.match(LANGUAGE)
							Language.new(match[:name], match[:q])
						else
							raise ParseError.new("Could not parse language: #{value.inspect}")
						end
					end
				end
			end
		end
	end
end
