# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

class IO
	module Event
		# @namespace
		module Support
			# Check if the `IO::Buffer` class is available.
			def self.buffer?
				IO.const_defined?(:Buffer)
			end
		end
	end
end
