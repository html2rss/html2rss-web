# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "stringio"

class StringIO
	unless method_defined?(:timeout)
		# Return the configured timeout for this in-memory stream.
		# @returns [Numeric | Nil] The configured timeout, if any.
		def timeout
			@timeout
		end
	end
	
	unless method_defined?(:timeout=)
		# Store timeout state for compatibility with IO-like timeout interfaces.
		# @parameter duration [Numeric | Nil] The timeout to assign.
		# @returns [Numeric | Nil] The assigned timeout.
		def timeout=(duration)
			@timeout = duration
		end
	end
end
