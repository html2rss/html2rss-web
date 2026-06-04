# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2025, by William T. Nelson.

require_relative "wrapper"
require_relative "buffered"

module Protocol
	module HTTP
		module Body
			# A body which buffers all its contents as it is read.
			#
			# As the body is buffered in memory, you may want to ensure your server has sufficient (virtual) memory available to buffer the entire body.
			class Rewindable < Wrapper
				# Wrap the given message body in a rewindable body, if it is not already rewindable.
				#
				# @parameter message [Request | Response] the message to wrap.
				def self.wrap(message)
					if body = message.body
						if body.rewindable?
							body
						else
							message.body = self.new(body)
						end
					end
				end
				
				# Initialize the body with the given body.
				#
				# @parameter body [Readable] the body to wrap.
				def initialize(body)
					super(body)
					
					@chunks = []
					@index = 0
				end
				
				# @returns [Boolean] Whether the body is empty.
				def empty?
					(@index >= @chunks.size) && super
				end
				
				# @returns [Boolean] Whether the body is ready to be read.
				def ready?
					(@index < @chunks.size) || super
				end
				
				# A rewindable body wraps some other body. Convert it to a buffered body. The buffered body will share the same chunks as the rewindable body.
				#
				# @returns [Buffered] the buffered body. 
				def buffered
					Buffered.new(@chunks)
				end
				
				# Read the next available chunk. This may return a buffered chunk if the stream has been rewound, or a chunk from the underlying stream, if available.
				#
				# @returns [String | Nil] The chunk of data, or `nil` if the stream has finished.
				def read
					if @index < @chunks.size
						chunk = @chunks[@index]
						@index += 1
					else
						if chunk = super
							@chunks << -chunk
							@index += 1
						end
					end
					
					# We dup them on the way out, so that if someone modifies the string, it won't modify the rewindability.
					return chunk
				end
				
				# Rewind the stream to the beginning.
				def rewind
					@index = 0
				end
				
				# @returns [Boolean] Whether the stream is rewindable, which it is.
				def rewindable?
					true
				end
				
				# Convert the body to a hash suitable for serialization.
				#
				# @returns [Hash] The body as a hash.
				def as_json(...)
					super.merge(
						index: @index,
						chunks: @chunks.size
					)
				end
				
				# Inspect the rewindable body.
				#
				# @returns [String] a string representation of the body.
				def inspect
					"#{super} | #<#{self.class} #{@index}/#{@chunks.size} chunks read>"
				end
			end
		end
	end
end
