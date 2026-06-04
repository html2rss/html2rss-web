# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2025, by William T. Nelson.

require_relative "readable"

module Protocol
	module HTTP
		module Body
			# Represents a body suitable for HEAD requests, in other words, a body that is empty and has a known length.
			class Head < Readable
				# Create a head body for the given body, capturing its length and then closing it.
				#
				# If a body is provided, the length is determined from the body, and the body is closed.
				# If no body is provided, and the content length is provided, a head body is created with that length.
				# This is useful for creating a head body when you only know the content length but not the actual body, which may happen in adapters for HTTP applications where the application may not provide a body for HEAD requests, but the content length is known.
				#
				# @parameter body [Readable | Nil] the body to create a head for.
				# @parameter length [Integer | Nil] the content length of the body, if known.
				# @returns [Head | Nil] the head body, or nil if the body is nil.
				def self.for(body, length = nil)
					if body
						head = self.new(body.length)
						body.close
						return head
					elsif length
						return self.new(length)
					end
					
					return nil
				end
				
				# Initialize the head body with the given length.
				#
				# @parameter length [Integer] the length of the body.
				def initialize(length)
					@length = length
				end
				
				# @returns [Boolean] the body is empty.
				def empty?
					true
				end
				
				# @returns [Boolean] the body is ready.
				def ready?
					true
				end
				
				# @returns [Integer] the length of the body, if known.
				def length
					@length
				end
				
				# Inspect the head body.
				#
				# @returns [String] a string representation of the head body.
				def inspect
					"#<#{self.class} #{@length} bytes (empty)>"
				end
			end
		end
	end
end
