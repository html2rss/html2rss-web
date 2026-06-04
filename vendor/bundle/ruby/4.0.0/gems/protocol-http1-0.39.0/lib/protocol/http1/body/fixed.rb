# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "protocol/http/body/readable"

module Protocol
	module HTTP1
		module Body
			# Represents a fixed length body.
			class Fixed < HTTP::Body::Readable
				# Initialize the body with the given connection and length.
				#
				# @parameter connection [Protocol::HTTP1::Connection] the connection to read the body from.
				# @parameter length [Integer] the length of the body.
				def initialize(connection, length)
					@connection = connection
					
					@length = length
					@remaining = length
				end
				
				# @attribute [Integer] the length of the body.
				attr :length
				
				# @attribute [Integer] the remaining bytes to read.
				attr :remaining
				
				# @returns [Boolean] true if the body is empty.
				def empty?
					@connection.nil? or @remaining == 0
				end
				
				# Close the connection.
				#
				# @parameter error [Exception | Nil] the error that caused the connection to be closed, if any.
				def close(error = nil)
					if connection = @connection
						@connection = nil
						
						unless @remaining == 0
							connection.close_read
						end
					end
					
					super
				end
				
				# Read a chunk of data.
				#
				# @returns [String | Nil] the next chunk of data.
				# @raises [EOFError] if the connection is closed before the expected length is read.
				def read
					if @remaining > 0
						if @connection
							# `readpartial` will raise `EOFError` if the connection is finished, or `IOError` if the connection is closed.
							chunk = @connection.readpartial(@remaining)
							
							@remaining -= chunk.bytesize
							
							if @remaining == 0
								@connection.receive_end_stream!
								@connection = nil
							end
							
							return chunk
						end
						
						# If the connection has been closed before we have read the expected length, raise an error:
						raise EOFError, "connection closed before expected length was read!"
					end
				end
				
				# @returns [String] a human-readable representation of the body.
				def inspect
					"#<#{self.class} #{@length} bytes, #{@remaining} remaining, #{empty? ? 'finished' : 'reading'}>"
				end
				
				# @returns [Hash] JSON representation for tracing and debugging.
				def as_json(...)
					super.merge(
						remaining: @remaining,
						state: @connection ? "open" : "closed"
					)
				end
			end
		end
	end
end
