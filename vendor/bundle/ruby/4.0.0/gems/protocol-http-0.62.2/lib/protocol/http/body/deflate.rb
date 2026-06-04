# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require_relative "wrapper"

require "zlib"

module Protocol
	module HTTP
		module Body
			# A body which compresses or decompresses the contents using the DEFLATE or GZIP algorithm.
			class ZStream < Wrapper
				# The default compression level.
				DEFAULT_LEVEL = 7
				
				# The DEFLATE window size.
				DEFLATE = -Zlib::MAX_WBITS
				
				# The GZIP window size.
				GZIP =  Zlib::MAX_WBITS | 16
				
				# The supported encodings.
				ENCODINGS = {
					"deflate" => DEFLATE,
					"gzip" => GZIP,
				}
				
				# Initialize the body with the given stream.
				#
				# @parameter body [Readable] the body to wrap.
				# @parameter stream [Zlib::Deflate | Zlib::Inflate] the stream to use for compression or decompression.
				def initialize(body, stream)
					super(body)
					
					@stream = stream
					
					@input_length = 0
					@output_length = 0
				end
				
				# Close the stream.
				#
				# @parameter error [Exception | Nil] the error that caused the stream to be closed.
				def close(error = nil)
					if stream = @stream
						@stream = nil
						stream.close unless stream.closed?
					end
					
					super
				end
				
				# The length of the output, if known. Generally, this is not known due to the nature of compression.
				def length
					# We don't know the length of the output until after it's been compressed.
					nil
				end
				
				# @attribute [Integer] input_length the total number of bytes read from the input.
				attr :input_length
				
				# @attribute [Integer] output_length the total number of bytes written to the output.
				attr :output_length
				
				# The compression ratio, according to the input and output lengths.
				#
				# @returns [Float] the compression ratio, e.g. 0.5 for 50% compression.
				def ratio
					if @input_length != 0
						@output_length.to_f / @input_length.to_f
					else
						1.0
					end
				end
				
				# Convert the body to a hash suitable for serialization.
				#
				# @returns [Hash] The body as a hash.
				def as_json(...)
					super.merge(
						input_length: @input_length,
						output_length: @output_length,
						compression_ratio: (ratio * 100).round(2)
					)
				end
				
				# Inspect the body, including the compression ratio.
				#
				# @returns [String] a string representation of the body.
				def inspect
					"#{super} | #<#{self.class} #{(ratio*100).round(2)}%>"
				end
			end
			
			# A body which compresses the contents using the DEFLATE or GZIP algorithm.
			class Deflate < ZStream
				# Create a new body which compresses the given body using the GZIP algorithm by default.
				#
				# @parameter body [Readable] the body to wrap.
				# @parameter window_size [Integer] the window size to use for compression.
				# @parameter level [Integer] the compression level to use.
				# @returns [Deflate] the wrapped body.
				def self.for(body, window_size = GZIP, level = DEFAULT_LEVEL)
					self.new(body, Zlib::Deflate.new(level, window_size))
				end
				
				# Read a chunk from the underlying body and compress it. If the body is finished, the stream is flushed and finished, and the remaining data is returned.
				#
				# @returns [String | Nil] the compressed chunk or `nil` if the stream is closed.
				def read
					return if @stream.finished?
					
					# The stream might have been closed while waiting for the chunk to come in.
					while chunk = super
						unless chunk.empty?
							@input_length += chunk.bytesize
							
							chunk = @stream.deflate(chunk, Zlib::SYNC_FLUSH)
							
							@output_length += chunk.bytesize
							
							return chunk
						end
					end
					
					if !@stream.closed?
						chunk = @stream.finish
						
						@output_length += chunk.bytesize
						
						return chunk.empty? ? nil : chunk
					end
				end
			end
		end
	end
end
