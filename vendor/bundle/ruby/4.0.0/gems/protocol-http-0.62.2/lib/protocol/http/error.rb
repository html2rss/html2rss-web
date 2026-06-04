# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

module Protocol
	module HTTP
		# A generic, HTTP protocol error.
		class Error < StandardError
		end
		
		# Raised when an HTTP stream or request was refused before any processing occurred.
		# In the case of requests, it indicates that the request was refused before any processing occurred, and can be safely retried.
		class RefusedError < Error
		end
		
		# @deprecated Use {RefusedError} instead.
		RequestRefusedError = RefusedError
		
		# Represents a bad request error (as opposed to a server error).
		# This is used to indicate that the request was malformed or invalid.
		module BadRequest
		end
		
		# Raised when a singleton (e.g. `content-length`) header is duplicated in a request or response.
		class DuplicateHeaderError < Error
			include BadRequest
			
			# @parameter key [String] The header key that was duplicated.
			def initialize(key, existing_value, new_value)
				super("Duplicate singleton header key: #{key.inspect}")
				
				@key = key
				@existing_value = existing_value
				@new_value = new_value
			end
			
			# @attribute [String] key The header key that was duplicated.
			attr :key
			
			# @attribute [String] existing_value The existing value for the duplicated header.
			attr :existing_value
			
			# @attribute [String] new_value The new value for the duplicated header.
			attr :new_value
			
			# Provides a detailed error message including the existing and new values.
			# @parameter highlight [Boolean] Whether to highlight the message (not currently used).
			# @return [String] The detailed error message.
			def detailed_message(highlight: false)
				<<~MESSAGE
					#{self.message}
						Existing value: #{@existing_value.inspect}
						New value: #{@new_value.inspect}
				MESSAGE
			end
		end
		
		# Raised when an invalid trailer header is encountered in headers.
		class InvalidTrailerError < Error
			include BadRequest
			
			# @parameter key [String] The trailer key that is invalid.
			def initialize(key)
				super("Invalid trailer key: #{key.inspect}")
			end
			
			# @attribute [String] key The trailer key that is invalid.
			attr :key
		end
	end
end
