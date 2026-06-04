# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module Protocol
	module HTTP
		# According to https://tools.ietf.org/html/rfc7231#appendix-C
		TOKEN = /[!#$%&'*+\-.^_`|~0-9A-Z]+/i
		
		QUOTED_STRING = /"(?:.(?!(?<!\\)"))*.?"/
		
		# https://tools.ietf.org/html/rfc7231#section-5.3.1
		QVALUE = /0(\.[0-9]{0,3})?|1(\.[0]{0,3})?/
		
		# Handling of HTTP quoted strings.
		module QuotedString
			# Unquote a "quoted-string" value according to <https://tools.ietf.org/html/rfc7230#section-3.2.6>. It should already match the QUOTED_STRING pattern above by the parser.
			def self.unquote(value, normalize_whitespace = true)
				value = value[1...-1]
				
				value.gsub!(/\\(.)/, '\1')
				
				if normalize_whitespace
					# LWS = [CRLF] 1*( SP | HT )
					value.gsub!(/[\r\n]+\s+/, " ")
				end
				
				return value
			end
			
			QUOTES_REQUIRED = /[()<>@,;:\\"\/\[\]?={} \t]/
			
			# Quote a string for HTTP header values if required.
			#
			# @raises [ArgumentError] if the value contains invalid characters like control characters or newlines.
			def self.quote(value, force = false)
				# Check if quoting is required:
				if value =~ QUOTES_REQUIRED or force
					"\"#{value.gsub(/["\\]/, '\\\\\0')}\""
				else
					value
				end
			end
		end
	end
end
