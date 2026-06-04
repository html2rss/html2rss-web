# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2022, by Dan Olson.

module Protocol
	module HTTP
		module Body
			# General operations for interacting with a request or response body.
			#
			# This module is included in both {Request} and {Response}.
			module Reader
				# Read chunks from the body.
				#
				# @yields {|chunk| ...} chunks from the body.
				def each(&block)
					if @body
						@body.each(&block)
						@body = nil
					end
				end
				
				# Reads the entire request/response body.
				#
				# @returns [String] the entire body as a string.
				def read
					if @body
						buffer = @body.join
						@body = nil
						
						return buffer
					end
				end
				
				# Gracefully finish reading the body. This will buffer the remainder of the body.
				#
				# @returns [Buffered] buffers the entire body.
				def finish
					if @body
						body = @body.finish
						@body = nil
						
						return body
					end
				end
				
				# Discard the body as efficiently as possible.
				def discard
					if body = @body
						@body = nil
						body.discard
					end
					
					return nil
				end
				
				# Buffer the entire request/response body.
				#
				# @returns [Reader] itself.
				def buffered!
					if @body
						@body = @body.finish
					end
					
					# TODO Should this return @body instead? It seems more useful.
					return self
				end
				
				# Write the body of the response to the given file path.
				#
				# @parameter path [String] the path to write the body to.
				# @parameter mode [Integer] the mode to open the file with.
				# @parameter options [Hash] additional options to pass to `File.open`.
				def save(path, mode = ::File::WRONLY|::File::CREAT|::File::TRUNC, **options)
					if @body
						::File.open(path, mode, **options) do |file|
							self.each do |chunk|
								file.write(chunk)
							end
						end
					end
				end
				
				# Close the connection as quickly as possible. Discards body. May close the underlying connection if necessary to terminate the stream.
				#
				# @parameter error [Exception | Nil] the error that caused the stream to be closed, if any.
				def close(error = nil)
					if @body
						@body.close(error)
						@body = nil
					end
				end
				
				# Whether there is a body?
				#
				# @returns [Boolean] whether there is a body.
				def body?
					@body and !@body.empty?
				end
			end
		end
	end
end
