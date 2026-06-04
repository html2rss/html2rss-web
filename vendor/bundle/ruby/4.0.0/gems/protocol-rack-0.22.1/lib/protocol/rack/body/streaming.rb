# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "protocol/http/body/streamable"

module Protocol
	module Rack
		module Body
			# Wraps a Rack streaming response body.
			# The body must be callable and accept a stream argument.
			# When closed, this class ensures the wrapped body's `close` method is called if it exists.
			class Streaming < ::Protocol::HTTP::Body::Streamable::ResponseBody
				# Initialize the streaming body wrapper.
				# 
				# @parameter body [Object] A callable object that accepts a stream argument, such as a Proc or an object that responds to `call`. May optionally respond to `close` for cleanup (e.g., `Rack::BodyProxy`).
				# @parameter input [Protocol::HTTP::Body::Readable | Nil] Optional input body for bi-directional streaming.
				def initialize(body, input = nil)
					@body = body
					
					super
				end
				
				# Close the streaming body and clean up resources.
				# If the wrapped body responds to `close`, it will be called to allow proper cleanup.
				# This ensures that `Rack::BodyProxy` cleanup callbacks are invoked correctly.
				# 
				# @parameter error [Exception | Nil] Optional error that caused the stream to close.
				def close(error = nil)
					if body = @body
						@body = nil
						if body.respond_to?(:close)
							body.close
						end
					end
					
					super
				end
			end
		end
	end
end
