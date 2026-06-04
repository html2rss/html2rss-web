# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "split"
require_relative "../quoted_string"
require_relative "../error"

module Protocol
	module HTTP
		module Header
			# The `accept-charset` header represents a list of character sets that the client can accept.
			class AcceptCharset < Split
				ParseError = Class.new(Error)
				
				# https://tools.ietf.org/html/rfc7231#section-5.3.3
				CHARSET = /\A(?<name>#{TOKEN})(;q=(?<q>#{QVALUE}))?\z/
				
				Charset = Struct.new(:name, :q) do
					def quality_factor
						(q || 1.0).to_f
					end
					
					def <=> other
						other.quality_factor <=> self.quality_factor
					end
				end
				
				# Parse the `accept-charset` header value into a list of character sets.
				#
				# @returns [Array(Charset)] the list of character sets and their associated quality factors.
				def charsets
					self.map do |value|
						if match = value.match(CHARSET)
							Charset.new(match[:name], match[:q])
						else
							raise ParseError.new("Could not parse character set: #{value.inspect}")
						end
					end
				end
			end
		end
	end
end
