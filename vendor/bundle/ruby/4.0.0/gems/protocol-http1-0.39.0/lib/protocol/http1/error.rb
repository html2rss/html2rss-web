# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "protocol/http/error"

module Protocol
	module HTTP1
		# The base class for all HTTP/1.x errors.
		class Error < HTTP::Error
		end
		
		# The protocol was violated in some way, e.g. trying to write a request while reading a response.
		class ProtocolError < Error
		end
		
		# The request line was too long.
		class LineLengthError < Error
		end
		
		# The request was not able to be parsed correctly, or failed some kind of validation.
		class BadRequest < Error
			include Protocol::HTTP::BadRequest
		end
		
		# A header name or value was invalid, e.g. contains invalid characters.
		class BadHeader < BadRequest
		end
		
		# Indicates that the request is invalid for some reason, e.g. syntax error, invalid headers, etc.
		class InvalidRequest < BadRequest
		end
		
		# The specified content length and the given content's length do not match.
		class ContentLengthError < Error
		end
	end
end
