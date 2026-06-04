# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

module IO::Stream
	# A specialized string buffer for binary data with automatic encoding handling.
	class StringBuffer < String
		BINARY = Encoding::BINARY
		
		# Initialize a new string buffer with binary encoding.
		def initialize
			super
			
			force_encoding(BINARY)
		end
		
		# Append a string to the buffer, converting to binary encoding if necessary.
		# @parameter string [String] The string to append.
		# @returns [StringBuffer] Self for method chaining.
		def << string
			if string.encoding == BINARY
				super(string)
			else
				super(string.b)
			end
			
			return self
		end
		
		alias concat <<
	end
end
