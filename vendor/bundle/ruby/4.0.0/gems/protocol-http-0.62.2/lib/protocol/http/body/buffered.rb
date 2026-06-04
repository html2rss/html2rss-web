# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2020, by Bryan Powell.
# Copyright, 2025, by William T. Nelson.

require_relative "readable"

module Protocol
	module HTTP
		module Body
			# A body which buffers all its contents.
			class Buffered < Readable
				# Tries to wrap an object in a {Buffered} instance.
				#
				# For compatibility, also accepts anything that behaves like an `Array(String)`.
				#
				# @parameter body [String | Array(String) | Readable | nil] the body to wrap.
				# @returns [Readable | nil] the wrapped body or nil if nil was given.
				def self.wrap(object)
					if object.is_a?(Readable)
						return object
					elsif object.is_a?(Array)
						return self.new(object)
					elsif object.is_a?(String)
						return self.new([object])
					elsif object
						return self.read(object)
					end
				end
				
				# Read the entire body into a buffered representation.
				#
				# @parameter body [Readable] the body to read.
				# @returns [Buffered] the buffered body.
				def self.read(body)
					chunks = []
					
					body.each do |chunk|
						chunks << chunk
					end
					
					self.new(chunks)
				end
				
				# Initialize the buffered body with some chunks.
				#
				# @parameter chunks [Array(String)] the chunks to buffer.
				# @parameter length [Integer] the length of the body, if known.
				def initialize(chunks = [], length = nil)
					@chunks = chunks
					@length = length
					
					@index = 0
				end
				
				# @attribute [Array(String)] chunks the buffered chunks.
				attr :chunks
				
				# A rewindable body wraps some other body. Convert it to a buffered body. The buffered body will share the same chunks as the rewindable body.
				#
				# @returns [Buffered] the buffered body.
				def buffered
					self.class.new(@chunks)
				end
				
				# Finish the body, this is a no-op.
				#
				# @returns [Buffered] self.
				def finish
					self
				end
				
				# Ensure that future reads return `nil`, but allow for rewinding.
				#
				# @parameter error [Exception | Nil] the error that caused the body to be closed, if any.
				def close(error = nil)
					@index = @chunks.length
					
					return nil
				end
				
				# Clear the buffered chunks.
				def clear
					@chunks = []
					@length = 0
					@index = 0
				end
				
				# The length of the body. Will compute and cache the length of the body, if it was not provided.
				def length
					@length ||= @chunks.inject(0){|sum, chunk| sum + chunk.bytesize}
				end
				
				# @returns [Boolean] if the body is empty.
				def empty?
					@index >= @chunks.length
				end
				
				# Whether the body is ready to be read.
				# @returns [Boolean] a buffered response is always ready.
				def ready?
					true
				end
				
				# Read the next chunk from the buffered body.
				#
				# @returns [String | Nil] the next chunk or nil if there are no more chunks.
				def read
					return nil unless @chunks
					
					if chunk = @chunks[@index]
						@index += 1
						
						return chunk.dup
					end
				end
				
				# Discard the body. Invokes {#close}.
				def discard
					# It's safe to call close here because there is no underlying stream to close:
					self.close
				end
				
				# Write a chunk to the buffered body.
				def write(chunk)
					@chunks << chunk
				end
				
				# Close the body for writing. This is a no-op.
				def close_write(error)
					# Nothing to do.
				end
				
				# Whether the body can be rewound.
				#
				# @returns [Boolean] if the body has chunks.
				def rewindable?
					@chunks != nil
				end
				
				# Rewind the body to the beginning, causing a subsequent read to return the first chunk.
				def rewind
					return false unless @chunks
					
					@index = 0
					
					return true
				end
				
				# Inspect the buffered body.
				#
				# @returns [String] a string representation of the buffered body.
				def inspect
					if @chunks and @chunks.size > 0
						"#<#{self.class} #{@index}/#{@chunks.size} chunks, #{self.length} bytes>"
					else
						"#<#{self.class} empty>"
					end
				end
			end
		end
	end
end
