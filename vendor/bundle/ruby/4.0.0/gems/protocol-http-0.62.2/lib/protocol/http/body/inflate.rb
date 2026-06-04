# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "zlib"

require_relative "deflate"

module Protocol
	module HTTP
		module Body
			# A body which decompresses the contents using the DEFLATE or GZIP algorithm.
			class Inflate < ZStream
				# Create a new body which decompresses the given body using the GZIP algorithm by default.
				#
				# @parameter body [Readable] the body to wrap.
				# @parameter window_size [Integer] the window size to use for decompression.
				def self.for(body, window_size = GZIP)
					self.new(body, Zlib::Inflate.new(window_size))
				end
				
				# Read from the underlying stream and inflate it.
				#
				# @returns [String | Nil] the inflated data, or nil if the stream is finished.
				def read
					if stream = @stream
						# Read from the underlying stream and inflate it:
						while chunk = super
							@input_length += chunk.bytesize
							
							# It's possible this triggers the stream to finish.
							chunk = stream.inflate(chunk)
							
							break unless chunk&.empty?
						end
						
						if chunk
							@output_length += chunk.bytesize
						elsif !stream.closed?
							chunk = stream.finish
							@output_length += chunk.bytesize
						end
						
						# If the stream is finished, we need to close it and potentially return nil:
						if stream.finished?
							@stream = nil
							stream.close
							
							while super
								# There is data left in the stream, so we need to keep reading until it's all consumed.
							end
							
							if chunk.empty?
								return nil
							end
						end
						
						return chunk
					end
				end
			end
		end
	end
end
