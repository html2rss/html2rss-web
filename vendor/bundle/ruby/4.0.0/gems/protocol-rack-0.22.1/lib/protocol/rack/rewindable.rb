# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "protocol/http/body/rewindable"
require "protocol/http/middleware"

module Protocol
	module Rack
		# Content-type driven input buffering, specific to the needs of `rack`.
		# This middleware ensures that request bodies for certain content types
		# can be read multiple times, which is required by Rack's specification.
		class Rewindable < ::Protocol::HTTP::Middleware
			# Media types that require buffering.
			# These types typically contain form data or file uploads that may need
			# to be read multiple times by Rack applications.
			BUFFERED_MEDIA_TYPES = %r{
				application/x-www-form-urlencoded|
				multipart/form-data|
				multipart/related|
				multipart/mixed
			}x
			
			# The HTTP POST method.
			POST = "POST"
			
			# Initialize the rewindable middleware.
			# 
			# @parameter app [Protocol::HTTP::Middleware] The middleware to wrap.
			def initialize(app)
				super(app)
			end
			
			# Determine whether the request needs a rewindable body.
			# A request needs a rewindable body if:
			# - It's a POST request with no content type (legacy behavior)
			# - It has a content type that matches BUFFERED_MEDIA_TYPES
			# 
			# @parameter request [Protocol::HTTP::Request] The request to check.
			# @returns [Boolean] True if the request body should be rewindable.
			def needs_rewind?(request)
				content_type = request.headers["content-type"]
				
				if request.method == POST and content_type.nil?
					return true
				end
				
				if BUFFERED_MEDIA_TYPES =~ content_type
					return true
				end
				
				return false
			end
			
			# Create a Rack environment from the request.
			# Delegates to the wrapped middleware.
			# 
			# @parameter request [Protocol::HTTP::Request] The request to create an environment from.
			# @returns [Hash] The Rack environment hash.
			def make_environment(request)
				@delegate.make_environment(request)
			end
			
			# Wrap the request body in a rewindable buffer if required.
			# If the request needs a rewindable body, wraps it in a {Protocol::HTTP::Body::Rewindable}.
			# 
			# @parameter request [Protocol::HTTP::Request] The request to process.
			# @returns [Protocol::HTTP::Response] The response from the wrapped middleware.
			def call(request)
				if body = request.body and needs_rewind?(request)
					request.body = Protocol::HTTP::Body::Rewindable.new(body)
				end
				
				return super
			end
		end
	end
end
