# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "protocol/http/body/readable"
require "protocol/http/body/buffered"
require "protocol/http/body/file"

require_relative "../adapter/version"

module Protocol
	module Rack
		module Body
			# Wraps a Rack response body that responds to `each`.
			# The body must only yield `String` values and may optionally respond to `close`.
			# This class provides both streaming and buffered access to the response body.
			class Enumerable < ::Protocol::HTTP::Body::Readable
				# The content-length header key.
				CONTENT_LENGTH = "content-length".freeze
				
				if Adapter::VERSION >= "3"
					# Wraps a Rack response body into an {Enumerable} instance.
					# If the body is an Array, its total size is calculated automatically.
					# 
					# @parameter body [Object] The Rack response body that responds to `each`.
					# @parameter length [Integer] Optional content length of the response body.
					# @returns [Enumerable] A new enumerable body instance.
					def self.wrap(body, length = nil)
						if body.respond_to?(:to_ary)
							# This avoids allocating an enumerator, which is more efficient:
							return ::Protocol::HTTP::Body::Buffered.new(body.to_ary, length)
						else
							return self.new(body, length)
						end
					end
				else
					def self.wrap(body, length = nil)
						# Rack 2 does not specify or implement `to_ary` behaviour correctly, so the best we can do is check if it's an Array directly:
						if body.is_a?(Array)
							# This avoids allocating an enumerator, which is more efficient:
							return ::Protocol::HTTP::Body::Buffered.new(body, length)
						else
							return self.new(body, length)
						end
					end
				end
				
				# Initialize the enumerable body wrapper.
				# 
				# @parameter body [Object] The Rack response body that responds to `each`.
				# @parameter length [Integer] The content length of the response body.
				def initialize(body, length)
					@length = length
					@body = body
					
					@chunks = nil
				end
				
				# @attribute [Object] The wrapped Rack response body.
				attr :body
				
				# @attribute [Integer] The total size of the response body in bytes.
				attr :length
				
				# Check if the response body is empty.
				# A body is considered empty if its length is 0 or if it responds to `empty?` and is empty.
				# 
				# @returns [Boolean] True if the body is empty.
				def empty?
					@length == 0 or (@body.respond_to?(:empty?) and @body.empty?)
				end
				
				# Check if the response body can be read immediately.
				# A body is ready if it's an Array or responds to `to_ary`.
				# 
				# @returns [Boolean] True if the body can be read immediately.
				def ready?
					body.is_a?(Array) or body.respond_to?(:to_ary)
				end
				
				# Close the response body.
				# If the body responds to `close`, it will be called.
				# 
				# @parameter error [Exception] Optional error that occurred during processing.
				def close(error = nil)
					@chunks = nil
					
					if body = @body
						@body = nil
						if body.respond_to?(:close)
							body.close
						end
					end
					
					super
				end
				
				# Enumerate the response body.
				# Each chunk yielded must be a String.
				# The body is automatically closed after enumeration.
				# 
				# @yields {|chunk| ...}
				# 	@parameter chunk [String] A chunk of the response body.
				def each(&block)
					@body.each(&block)
				rescue => error
					raise
				ensure
					self.close(error)
				end
				
				# Check if the body is a streaming response.
				# A body is streaming if it doesn't respond to `each`.
				# 
				# @returns [Boolean] True if the body is streaming.
				def stream?
					!@body.respond_to?(:each)
				end
				
				# Stream the response body to the given stream.
				# The body is automatically closed after streaming.
				# 
				# @parameter stream [Object] The stream to write the body to.
				def call(stream)
					@body.call(stream)
				rescue => error
					raise
				ensure
					self.close(error)
				end
				
				# Read the next chunk from the response body.
				# Returns nil when there are no more chunks.
				# 
				# @returns [String | Nil] The next chunk or nil if there are no more chunks.
				def read
					@chunks ||= @body.to_enum(:each)
					
					return @chunks.next
				rescue StopIteration
					return nil
				end
				
				# Get a string representation of the body.
				# 
				# @returns [String] A string describing the body's class and length.
				def inspect
					"\#<#{self.class} length=#{@length.inspect} body=#{@body.class}>"
				end
			end
		end
	end
end
