# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "methods"
require_relative "headers"
require_relative "request"
require_relative "response"

module Protocol
	module HTTP
		# The middleware interface provides a convenient wrapper for implementing HTTP middleware.
		#
		# A middleware instance generally needs to respond to two methods:
		#
		# - `call(request)` -> `response`
		# - `close()`
		#
		# The call method is called for each request. The close method is called when the server is shutting down.
		#
		# You do not need to use the Middleware class to implement middleware. You can implement the interface directly.
		class Middleware < Methods
			# Convert a block to a middleware delegate.
			#
			# @parameter block [Proc] The block to convert to a middleware delegate.
			# @returns [Middleware] The middleware delegate.
			def self.for(&block)
				# Add a close method to the block.
				def block.close
				end
				
				return self.new(block)
			end
			
			# Initialize the middleware with the given delegate.
			#
			# @parameter delegate [Object] The delegate object. A delegate is used for passing along requests that are not handled by *this* middleware.
			def initialize(delegate)
				@delegate = delegate
			end
			
			# @attribute [Object] The delegate object that is used for passing along requests that are not handled by *this* middleware.
			attr :delegate
			
			# Close the middleware. Invokes the close method on the delegate.
			def close
				@delegate.close
			end
			
			# Call the middleware with the given request. Invokes the call method on the delegate.
			def call(request)
				@delegate.call(request)
			end
			
			# A simple middleware that always returns a 200 response.
			module Okay
				# Close the middleware - idempotent no-op.
				def self.close
				end
				
				# Call the middleware with the given request, always returning a 200 response.
				#
				# @parameter request [Request] The request object.
				# @returns [Response] The response object, which always contains a 200 status code.
				def self.call(request)
					Response[200]
				end
			end
			
			# A simple middleware that always returns a 404 response.
			module NotFound
				# Close the middleware - idempotent no-op.
				def self.close
				end
				
				# Call the middleware with the given request, always returning a 404 response. This middleware is useful as a default.
				#
				# @parameter request [Request] The request object.
				# @returns [Response] The response object, which always contains a 404 status code.
				def self.call(request)
					Response[404]
				end
			end
			
			# A simple middleware that always returns "Hello World!".
			module HelloWorld
				# Close the middleware - idempotent no-op.
				def self.close
				end
				
				# Call the middleware with the given request.
				#
				# @parameter request [Request] The request object.
				# @returns [Response] The response object, whihc always contains "Hello World!".
				def self.call(request)
					Response[200, Headers["content-type" => "text/plain"], ["Hello World!"]]
				end
			end
		end
	end
end
