# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "protocol/http/body/readable"
require "protocol/http/body/stream"

module Protocol
	module Rack
		module Body
			# Wraps a Rack input object into a readable body.
			# This class provides a consistent interface for reading from Rack input streams,
			# which may be any IO-like object that responds to `read` and `close`.
			class InputWrapper < Protocol::HTTP::Body::Readable
				# The default block size for reading from the input stream.
				BLOCK_SIZE = 1024*4
				
				# Initialize the input wrapper.
				# 
				# @parameter io [Object] The input object that responds to `read` and `close`.
				# @parameter block_size [Integer] The size of chunks to read at a time.
				def initialize(io, block_size: BLOCK_SIZE)
					@io = io
					@block_size = block_size
					
					super()
				end
				
				# Close the input stream.
				# If the input object responds to `close`, it will be called.
				# 
				# @parameter error [Exception] Optional error that occurred during processing.
				def close(error = nil)
					if @io
						@io.close
						@io = nil
					end
				end
				
				# Read the next chunk from the input stream.
				# Returns nil when there is no more data to read.
				# 
				# @returns [String | Nil] The next chunk of data or nil if there is no more data.
				def read
					@io&.read(@block_size)
				end
			end
		end
	end
end
