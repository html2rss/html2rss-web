# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require_relative "body"
require_relative "constants"

require "protocol/http/response"
require "protocol/http/headers"
require "protocol/http/body/head"

module Protocol
	module Rack
		# A Rack-compatible HTTP response wrapper
		#
		# A Rack response consisting of `[status, headers, body]` includes various Rack-specific elements, including:
		#
		# - A `headers['rack.hijack']` callback which bypasses normal response handling.
		# - Potentially invalid content length.
		# - Potentially invalid body when processing a `HEAD` request.
		# - Newline-separated header values.
		# - Other `rack.` specific header key/value pairs.
		#
		# This wrapper takes those issues into account and adapts the Rack response tuple into a {Protocol::HTTP::Response}.
		class Response < ::Protocol::HTTP::Response
			# HTTP hop headers which *should* not be passed through the proxy.
			HOP_HEADERS = [
				"connection",
				"keep-alive",
				"public",
				"proxy-authenticate",
				"transfer-encoding",
				"upgrade",
			]
			
			# Wrap a Rack response into a {Response} instance.
			# 
			# @parameter env [Hash] The Rack environment hash.
			# @parameter status [Integer] The Rack response status code.
			# @parameter headers [Protocol::HTTP::Headers] The response headers.
			# @parameter meta [Hash] The Rack-specific metadata (e.g., `rack.hijack`).
			# @parameter body [Object] The Rack response body.
			# @parameter request [Protocol::HTTP::Request | Nil] The original request.
			# @returns [Response] A new response instance.
			def self.wrap(env, status, headers, meta, body, request = nil)
				ignored = headers.extract(HOP_HEADERS)
				
				unless ignored.empty?
					Console.warn(self, "Ignoring hop headers!", ignored: ignored)
				end
				
				if hijack_body = meta["rack.hijack"]
					body = hijack_body
				end
				
				body = Body.wrap(env, status, headers, body, request&.body, request&.head?)
				
				protocol = meta[RACK_PROTOCOL]
				
				# https://tools.ietf.org/html/rfc7231#section-7.4.2
				# headers.add('server', "falcon/#{Falcon::VERSION}")
				
				# https://tools.ietf.org/html/rfc7231#section-7.1.1.2
				# headers.add('date', Time.now.httpdate)
				
				return self.new(status, headers, body, protocol)
			end
			
			# Initialize the response wrapper.
			# 
			# @parameter status [Integer] The response status code.
			# @parameter headers [Protocol::HTTP::Headers] The response headers.
			# @parameter body [Protocol::HTTP::Body] The response body.
			# @parameter protocol [String | Nil] The response protocol for upgraded requests.
			def initialize(status, headers, body, protocol = nil)
				super(nil, status, headers, body, protocol)
			end
		end
	end
end
