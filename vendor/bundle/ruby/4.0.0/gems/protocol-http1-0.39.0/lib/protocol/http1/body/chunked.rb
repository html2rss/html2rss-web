# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require "protocol/http/body/readable"

module Protocol
	module HTTP1
		module Body
			# Represents a chunked body, which is a series of chunks, each with a length prefix.
			#
			# See https://tools.ietf.org/html/rfc7230#section-4.1 for more details on the chunked transfer encoding.
			class Chunked < HTTP::Body::Readable
				CRLF = "\r\n"
				
				# Initialize the chunked body.
				#
				# @parameter connection [Protocol::HTTP1::Connection] the connection to read the body from.
				# @parameter headers [Protocol::HTTP::Headers] the headers to read the trailer into, if any.
				def initialize(connection, headers)
					@connection = connection
					@finished = false
					
					@headers = headers
					
					@length = 0
					@count = 0
				end
				
				# @attribute [Integer] the number of chunks read so far.
				attr :count
				
				# @attribute [Integer] the length of the body if known.
				def length
					# We only know the length once we've read the final chunk:
					if @finished
						@length
					end
				end
				
				# @returns [Boolean] true if the body is empty, in other words {read} will return `nil`.
				def empty?
					@connection.nil?
				end
				
				# Close the connection and mark the body as finished.
				#
				# @parameter error [Exception | Nil] the error that caused the body to be closed, if any.
				def close(error = nil)
					if connection = @connection
						@connection = nil
						
						unless @finished
							connection.close_read
						end
					end
					
					super
				end
				
				VALID_CHUNK_LENGTH = /\A[0-9a-fA-F]+\z/
				
				# Read a chunk of data.
				#
				# Follows the procedure outlined in https://tools.ietf.org/html/rfc7230#section-4.1.3
				#
				# @returns [String | Nil] the next chunk of data, or `nil` if the body is finished.
				# @raises [EOFError] if the connection is closed before the expected length is read.
				def read
					if !@finished
						if @connection
							length, _extensions = @connection.read_line.split(";", 2)
							
							unless length =~ VALID_CHUNK_LENGTH
								raise BadRequest, "Invalid chunk length: #{length.inspect}"
							end
							
							# It is possible this line contains chunk extension, so we use `to_i` to only consider the initial integral part:
							length = Integer(length, 16)
							
							if length == 0
								read_trailer
								
								# The final chunk has been read and the connection is now closed:
								@connection.receive_end_stream!
								@connection = nil
								@finished = true
								
								return nil
							end
							
							# Read trailing CRLF:
							chunk = @connection.read(length + 2)
							
							if chunk.bytesize == length + 2
								# ...and chomp it off:
								chunk.chomp!(CRLF)
								
								@length += length
								@count += 1
								
								return chunk
							else
								# The connection has been closed before we have read the requested length:
								@connection.close_read
								@connection = nil
							end
						end
						
						# If the connection has been closed before we have read the final chunk, raise an error:
						raise EOFError, "connection closed before expected length was read!"
					end
				end
				
				# @returns [String] a human-readable representation of the body.
				def inspect
					"\#<#{self.class} #{@length} bytes read in #{@count} chunks, #{@finished ? 'finished' : 'reading'}>"
				end
				
				# @returns [Hash] JSON representation for tracing and debugging.
				def as_json(...)
					super.merge(
						count: @count,
						finished: @finished,
						state: @connection ? "open" : "closed"
					)
				end
				
				private
				
				# Read the trailer from the connection, and add any headers to the trailer.
				def read_trailer
					while line = @connection.read_line?
						# Empty line indicates end of trailer:
						break if line.empty?
						
						if match = line.match(HEADER)
							@headers.add(match[1], match[2], trailer: true)
						else
							raise BadHeader, "Could not parse header: #{line.inspect}"
						end
					end
				end
			end
		end
	end
end
