# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "protocol/http/body/readable"

module Protocol
	module HTTP1
		module Body
			# Represents the remainder of the body, which reads all the data from the connection until it is finished.
			class Remainder < HTTP::Body::Readable
				BLOCK_SIZE = 1024 * 64
				
				# Initialize the body with the given connection.
				#
				# @parameter connection [Protocol::HTTP1::Connection] the connection to read the body from.
				def initialize(connection, block_size: BLOCK_SIZE)
					@connection = connection
					@block_size = block_size
				end
				
				# @returns [Boolean] true if the body is empty.
				def empty?
					@connection.nil?
				end
				
				# Discard the body, which will close the connection and prevent further reads.
				def discard
					if connection = @connection
						@connection = nil
						
						# Ensure no further requests can be read from the connection, as we are discarding the body which may not be fully read:
						connection.close_read
					end
				end
				
				# Close the connection.
				#
				# @parameter error [Exception | Nil] the error that caused the connection to be closed, if any.
				def close(error = nil)
					self.discard
					
					super
				end
				
				# Read a chunk of data.
				#
				# @returns [String | Nil] the next chunk of data.
				def read
					@connection&.readpartial(@block_size)
				rescue EOFError
					if connection = @connection
						@connection = nil
						connection.receive_end_stream!
					end
					
					return nil
				end
				
				# @returns [String] a human-readable representation of the body.
				def inspect
					"#<#{self.class} #{@block_size} byte blocks, #{empty? ? 'finished' : 'reading'}>"
				end
				
				# @returns [Hash] JSON representation for tracing and debugging.
				def as_json(...)
					super.merge(
						block_size: @block_size,
						state: @connection ? "open" : "closed"
					)
				end
			end
		end
	end
end
