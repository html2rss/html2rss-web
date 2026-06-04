# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require_relative "readable"

module Protocol
	module HTTP
		module Body
			# Wrapping body instance. Typically you'd override `#read`.
			class Wrapper < Readable
				# Wrap the body of the given message in a new instance of this class.
				#
				# @parameter message [Request | Response] the message to wrap.
				# @returns [Wrapper | Nil] the wrapped body or `nil`` if the body was `nil`.
				def self.wrap(message)
					if body = message.body
						message.body = self.new(body)
					end
				end
				
				# Initialize the wrapper with the given body.
				#
				# @parameter body [Readable] The body to wrap.
				def initialize(body)
					@body = body
				end
				
				# @attribute [Readable] The wrapped body.
				attr :body
				
				# Close the body.
				#
				# @parameter error [Exception | Nil] The error that caused this stream to be closed, if any.
				def close(error = nil)
					@body.close(error)
					
					# It's a no-op:
					# super
				end
				
				# Forwards to the wrapped body.
				def empty?
					@body.empty?
				end
				
				# Forwards to the wrapped body.
				def ready?
					@body.ready?
				end
				
				# Forwards to the wrapped body.
				def buffered
					@body.buffered
				end
				
				# Forwards to the wrapped body.
				def rewind
					@body.rewind
				end
				
				# Forwards to the wrapped body.
				def rewindable?
					@body.rewindable?
				end
				
				# Forwards to the wrapped body.
				def length
					@body.length
				end
				
				# Forwards to the wrapped body.
				def read
					@body.read
				end
				
				# Forwards to the wrapped body.
				def discard
					@body.discard
				end
				
				# Convert the body to a hash suitable for serialization.
				#
				# @returns [Hash] The body as a hash.
				def as_json(...)
					{
						class: self.class.name,
						body: @body&.as_json
					}
				end
				
				# Convert the body to JSON.
				#
				# @returns [String] The body as JSON.
				def to_json(...)
					as_json.to_json(...)
				end
				
				# Inspect the wrapped body. The wrapper, by default, is transparent.
				#
				# @returns [String] a string representation of the wrapped body.
				def inspect
					@body.inspect
				end
			end
		end
	end
end
