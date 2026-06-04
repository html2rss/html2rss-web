# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "split"
require_relative "../quoted_string"
require_relative "../error"

module Protocol
	module HTTP
		module Header
			# The `accept-encoding` header represents a list of encodings that the client can accept.
			class AcceptEncoding < Split
				ParseError = Class.new(Error)
				
				# https://tools.ietf.org/html/rfc7231#section-5.3.1
				QVALUE = /0(\.[0-9]{0,3})?|1(\.[0]{0,3})?/
				
				# https://tools.ietf.org/html/rfc7231#section-5.3.4
				ENCODING = /\A(?<name>#{TOKEN})(;q=(?<q>#{QVALUE}))?\z/
				
				Encoding = Struct.new(:name, :q) do
					def quality_factor
						(q || 1.0).to_f
					end
					
					def <=> other
						other.quality_factor <=> self.quality_factor
					end
				end
				
				# Parse the `accept-encoding` header value into a list of encodings.
				#
				# @returns [Array(Charset)] the list of character sets and their associated quality factors.
				def encodings
					self.map do |value|
						if match = value.match(ENCODING)
							Encoding.new(match[:name], match[:q])
						else
							raise ParseError.new("Could not parse encoding: #{value.inspect}")
						end
					end
				end
			end
		end
	end
end
