# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require_relative "middleware"

require_relative "body/buffered"
require_relative "body/inflate"

module Protocol
	module HTTP
		# A middleware that sets the accept-encoding header and decodes the response according to the content-encoding header.
		class AcceptEncoding < Middleware
			# The header used to request encodings.
			ACCEPT_ENCODING = "accept-encoding".freeze
			
			# The header used to specify encodings.
			CONTENT_ENCODING = "content-encoding".freeze
			
			# The default wrappers to use for decoding content.
			DEFAULT_WRAPPERS = {
				"gzip" => Body::Inflate.method(:for),
				"identity" => ->(body){body}, # Identity means no encoding
				
				# There is no point including this:
				# 'identity' => ->(body){body},
			}
			
			# Initialize the middleware with the given delegate and wrappers.
			#
			# @parameter delegate [Protocol::HTTP::Middleware] The delegate middleware.
			# @parameter wrappers [Hash] A hash of encoding names to wrapper functions.
			def initialize(delegate, wrappers = DEFAULT_WRAPPERS)
				super(delegate)
				
				@accept_encoding = wrappers.keys.join(", ")
				@wrappers = wrappers
			end
			
			# Set the accept-encoding header and decode the response body.
			#
			# @parameter request [Protocol::HTTP::Request] The request to modify.
			# @returns [Protocol::HTTP::Response] The response.
			def call(request)
				request.headers[ACCEPT_ENCODING] = @accept_encoding
				
				response = super
				
				if body = response.body and !body.empty?
					if content_encoding = response.headers[CONTENT_ENCODING]
						# Process encodings in reverse order and remove them when they are decoded:
						while name = content_encoding.last
							# Look up wrapper with case-insensitive matching:
							wrapper = @wrappers[name.downcase]
							
							if wrapper
								body = wrapper.call(body)
								# Remove the encoding we just processed:
								content_encoding.pop
							else
								# Unknown encoding - stop processing here:
								break
							end
						end
						
						# Update the response body:
						response.body = body
						
						# Remove the content-encoding header if we decoded all encodings:
						if content_encoding.empty?
							response.headers.delete(CONTENT_ENCODING)
						end
					end
				end
				
				return response
			end
		end
	end
end
