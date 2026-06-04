# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require_relative "body/streaming"
require_relative "body/enumerable"
require_relative "constants"

require "console"
require "protocol/http/body/completable"
require "protocol/http/body/head"

module Protocol
	module Rack
		# The Body module provides functionality for handling Rack response bodies.
		# It includes methods for wrapping different types of response bodies and handling completion callbacks.
		module Body
			# The `content-length` header key.
			CONTENT_LENGTH = "content-length"
			
			# Check if the given status code indicates no content should be returned.
			# Status codes 204 (No Content), 205 (Reset Content), and 304 (Not Modified) should not include a response body.
			# 
			# @parameter status [Integer] The HTTP status code.
			# @returns [Boolean] True if the status code indicates no content.
			def self.no_content?(status)
				status == 204 or status == 205 or status == 304
			end
			
			# Wrap a Rack response body into a {Protocol::HTTP::Body} instance.
			# Handles different types of response bodies:
			# - {Protocol::HTTP::Body::Readable} instances are returned as-is.
			# - Bodies that respond to `to_path` are wrapped in {Protocol::HTTP::Body::File}.
			# - Enumerable bodies are wrapped in {Body::Enumerable}.
			# - Other bodies are wrapped in {Body::Streaming}.
			# 
			# @parameter env [Hash] The Rack environment.
			# @parameter status [Integer] The HTTP status code.
			# @parameter headers [Hash] The response headers.
			# @parameter body [Object] The response body to wrap.
			# @parameter input [Object] Optional input for streaming bodies.
			# @parameter head [Boolean] Indicates if this is a HEAD request, which should not have a body.
			# @returns [Protocol::HTTP::Body] The wrapped response body.
			def self.wrap(env, status, headers, body, input = nil, head = false)
				# In no circumstance do we want this header propagating out:
				if length = headers.delete(CONTENT_LENGTH)
					# We don't really trust the user to provide the right length to the transport:
					length = Integer(length)
				end
				
				# If we have a Protocol::HTTP body, we return it directly:
				if body.is_a?(::Protocol::HTTP::Body::Readable)
					# Ignore.
				elsif status == 200 and body.respond_to?(:to_path)
					begin
						# Don't mangle partial responses (206):
						body = ::Protocol::HTTP::Body::File.open(body.to_path).tap do
							body.close if body.respond_to?(:close) # Close the original body.
						end
					rescue Errno::ENOENT
						# If the file is not available, ignore:
					end
				elsif body.respond_to?(:each)
					body = Body::Enumerable.wrap(body, length)
				elsif body
					body = Body::Streaming.new(body, input)
				else
					Console.warn(self, "Rack response body was nil, ignoring!")
				end
				
				if body and no_content?(status)
					unless body.empty?
						Console.warn(self, "Rack response body was not empty, and status code indicates no content!", body: body, status: status)
					end
					
					body.close
					body = nil
				end
				
				response_finished = env[RACK_RESPONSE_FINISHED]
				
				if response_finished&.any?
					if body
						body = ::Protocol::HTTP::Body::Completable.new(body, completion_callback(response_finished, env, status, headers))
					else
						completion_callback(response_finished, env, status, headers).call(nil)
					end
				end
				
				# There are two main situations we need to handle:
				# 1. The application has the `Rack::Head` middleware in the stack, which means we should not return a body, and the application is also responsible for setting the content-length header. `Rack::Head` will result in an empty enumerable body.
				# 2. The application does not have `Rack::Head`, in which case it will return a body and we need to extract the length.
				# In both cases, we need to ensure that the body is wrapped correctly. If there is no body and we don't know the length, we also just return `nil`.
				if head
					if body
						body = ::Protocol::HTTP::Body::Head.for(body)
					elsif length
						body = ::Protocol::HTTP::Body::Head.new(length)
					end
					# Otherwise, body is `nil` and we don't know the length either.
				end
				
				return body
			end
			
			# Create a completion callback for response finished handlers. The callback is called with any error that occurred during response processing.
			# 
			# Callbacks are invoked in reverse order of registration, as specified by the Rack specification.
			# If a callback raises an exception, it is caught and logged, but does not prevent other callbacks from being invoked.
			# 
			# @parameter response_finished [Array] Array of response finished callbacks.
			# @parameter env [Hash] The Rack environment.
			# @parameter status [Integer] The HTTP status code.
			# @parameter headers [Hash] The response headers.
			# @returns [Proc] A callback that calls all response finished handlers.
			def self.completion_callback(response_finished, env, status, headers)
				proc do |error|
					# Callbacks are invoked in reverse order of registration, as required by the Rack specification:
					response_finished.reverse_each do |callback|
						begin
							callback.call(env, status, headers, error)
						rescue => callback_error
							# If a callback raises an exception, log it but continue invoking other callbacks. The Rack specification states that callbacks should not raise exceptions, but we handle this gracefully to prevent one misbehaving callback from breaking others:
							Console.error(self, "Error occurred during response finished callback:", callback_error)
						end
					end
				end
			end
		end
	end
end
