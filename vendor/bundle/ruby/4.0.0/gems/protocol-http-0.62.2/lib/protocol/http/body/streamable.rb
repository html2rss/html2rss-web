# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "readable"
require_relative "writable"

require_relative "stream"

module Protocol
	module HTTP
		module Body
			# A body that invokes a block that can read and write to a stream.
			#
			# In some cases, it's advantageous to directly read and write to the underlying stream if possible. For example, HTTP/1 upgrade requests, WebSockets, and similar. To handle that case, response bodies can implement {stream?} and return `true`. When {stream?} returns true, the body **should** be consumed by calling `call(stream)`. Server implementations may choose to always invoke `call(stream)` if it's efficient to do so. Bodies that don't support it will fall back to using {each}.
			#
			# When invoking `call(stream)`, the stream can be read from and written to, and closed. However, the stream is only guaranteed to be open for the duration of the `call(stream)` call. Once the method returns, the stream **should** be closed by the server.
			module Streamable
				# Generate a new streaming request body using the given block to generate the body.
				#
				# @parameter block [Proc] The block that generates the body.
				# @returns [RequestBody] The streaming request body.
				def self.request(&block)
					RequestBody.new(block)
				end
				
				# Generate a new streaming response body using the given block to generate the body.
				#
				# @parameter request [Request] The request.
				# @parameter block [Proc] The block that generates the body.
				# @returns [ResponseBody] The streaming response body.
				def self.response(request, &block)
					ResponseBody.new(block, request.body)
				end
				
				# A output stream that can be written to by a block.
				class Output
					# Schedule the block to be executed in a fiber.
					#
					# @parameter input [Readable] The input stream.
					# @parameter block [Proc] The block that generates the output.
					# @returns [Output] The output stream.
					def self.schedule(input, block)
						self.new(input, block).tap(&:schedule)
					end
					
					# Initialize the output stream with the given input and block.
					#
					# @parameter input [Readable] The input stream.
					# @parameter block [Proc] The block that generates the output.
					def initialize(input, block)
						@output = Writable.new
						@stream = Stream.new(input, @output)
						@block = block
					end
					
					# Schedule the block to be executed in a fiber.
					#
					# @returns [Fiber] The fiber.
					def schedule
						@fiber ||= Fiber.schedule do
							@block.call(@stream)
						end
					end
					
					# Read from the output stream (may block).
					def read
						@output.read
					end
					
					# Close the output stream.
					#
					# @parameter error [Exception | Nil] The error that caused this stream to be closed, if any.
					def close(error = nil)
						@output.close_write(error)
					end
				end
				
				# Raised when a streaming body is consumed more than once.
				class ConsumedError < StandardError
				end
				
				# A streaming body that can be read from and written to.
				class Body < Readable
					# Initialize the body with the given block and input.
					#
					# @parameter block [Proc] The block that generates the body.
					# @parameter input [Readable] The input stream, if known.
					def initialize(block, input = nil)
						@block = block
						@input = input
						@output = nil
					end
					
					# @returns [Boolean] Whether the body can be streamed, which is true.
					def stream?
						true
					end
					
					# Invokes the block in a fiber which yields chunks when they are available.
					def read
						# We are reading chunk by chunk, allocate an output stream and execute the block to generate the chunks:
						if @output.nil?
							if @block.nil?
								raise ConsumedError, "Streaming body has already been consumed!"
							end
							
							@output = Output.schedule(@input, @block)
							@block = nil
						end
						
						@output.read
					end
					
					# Invoke the block with the given stream. The block can read and write to the stream, and must close the stream when finishing.
					#
					# @parameter stream [Stream] The stream to read and write to.
					def call(stream)
						if @block.nil?
							raise ConsumedError, "Streaming block has already been consumed!"
						end
						
						block = @block
						
						@input = @output = @block = nil
						
						# Ownership of the stream is passed into the block, in other words, the block is responsible for closing the stream.
						block.call(stream)
					rescue => error
						# If, for some reason, the block raises an error, we assume it may not have closed the stream, so we close it here:
						stream.close
						raise
					end
					
					# Close the input. The streaming body will eventually read all the input.
					#
					# @parameter error [Exception | Nil] The error that caused this stream to be closed, if any.
					def close_input(error = nil)
						if input = @input
							@input = nil
							input.close(error)
						end
					end
					
					# Close the output, the streaming body will be unable to write any more output.
					#
					# @parameter error [Exception | Nil] The error that caused this stream to be closed, if any.
					def close_output(error = nil)
						if output = @output
							@output = nil
							output.close(error)
						end
					end
					
					# Inspect the streaming body.
					#
					# @returns [String] a string representation of the streaming body.
					def inspect
						if @block
							"#<#{self.class} block available, not consumed>"
						elsif @output
							"#<#{self.class} block consumed, output active>"
						else
							"#<#{self.class} block consumed, output closed>"
						end
					end
				end
				
				# A response body is used on the server side to generate the response body using a block.
				class ResponseBody < Body
					# Close will be invoked when all the output is written.
					def close(error = nil)
						self.close_output(error)
					end
				end
				
				# A request body is used on the client side to generate the request body using a block.
				#
				# As the response body isn't available until the request is sent, the response body must be {stream}ed into the request body.
				class RequestBody < Body
					# Initialize the request body with the given block.
					#
					# @parameter block [Proc] The block that generates the body.
					def initialize(block)
						super(block, Writable.new)
					end
					
					# Close will be invoked when all the input is read.
					def close(error = nil)
						self.close_input(error)
					end
					
					# Stream the response body into the block's input.
					def stream(body)
						body&.each do |chunk|
							@input.write(chunk)
						end
					rescue => error
					ensure
						@input.close_write(error)
					end
				end
			end
		end
	end
end
