# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "middleware"

require_relative "body/buffered"
require_relative "body/deflate"

module Protocol
	module HTTP
		# Encode a response according the the request's acceptable encodings.
		class ContentEncoding < Middleware
			# The default wrappers to use for encoding content.
			DEFAULT_WRAPPERS = {
				"gzip" => Body::Deflate.method(:for)
			}
			
			# The default content types to apply encoding to.
			DEFAULT_CONTENT_TYPES = %r{^(text/.*?)|(.*?/json)|(.*?/javascript)$}
			
			# Initialize the content encoding middleware.
			#
			# @parameter delegate [Middleware] The next middleware in the chain.
			# @parameter content_types [Regexp] The content types to apply encoding to.
			# @parameter wrappers [Hash] The encoding wrappers to use.
			def initialize(delegate, content_types = DEFAULT_CONTENT_TYPES, wrappers = DEFAULT_WRAPPERS)
				super(delegate)
				
				@content_types = content_types
				@wrappers = wrappers
			end
			
			# Encode the response body according to the request's acceptable encodings.
			#
			# @parameter request [Request] The request.
			# @returns [Response] The response.
			def call(request)
				response = super
				
				# Early exit if the response has already specified a content-encoding.
				return response if response.headers["content-encoding"]
				
				# This is a very tricky issue, so we avoid it entirely.
				# https://lists.w3.org/Archives/Public/ietf-http-wg/2014JanMar/1179.html
				return response if response.partial?
				
				body = response.body
				
				# If there is no response body, there is nothing to encode:
				return response if body.nil? or body.empty?
				
				# Ensure that caches are aware we are varying the response based on the accept-encoding request header:
				response.headers.add("vary", "accept-encoding")
				
				if accept_encoding = request.headers["accept-encoding"]
					if content_type = response.headers["content-type"] and @content_types =~ content_type
						accept_encoding.each do |name|
							if wrapper = @wrappers[name]
								response.headers["content-encoding"] = name
								
								body = wrapper.call(body)
								
								break
							end
						end
						
						response.body = body
					end
				end
				
				return response
			end
		end
	end
end
