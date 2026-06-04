# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require "protocol/http/request"
require "protocol/http/headers"

require_relative "constants"
require_relative "body/input_wrapper"

module Protocol
	module Rack
		# A Rack-compatible HTTP request wrapper.
		#
		# This class provides a bridge between Rack's environment hash and {Protocol::HTTP::Request}. It handles conversion of Rack environment variables to HTTP request properties.
		class Request < ::Protocol::HTTP::Request
			# Get or create a Request instance for the given Rack environment.
			# The request is cached in the environment to avoid creating multiple instances.
			# 
			# @parameter env [Hash] The Rack environment hash.
			# @returns [Request] A Request instance for the environment.
			def self.[](env)
				env["protocol.http.request"] ||= new(env)
			end
			
			# Initialize a new Request instance from a Rack environment.
			# 
			# @parameter env [Hash] The Rack environment hash.
			def initialize(env)
				@env = env
				
				super(
					@env["rack.url_scheme"],
					@env["HTTP_HOST"],
					@env["REQUEST_METHOD"],
					@env["PATH_INFO"],
					@env["SERVER_PROTOCOL"],
					self.class.headers(@env),
					Body::InputWrapper.new(@env["rack.input"]),
					self.class.protocol(@env)
				)
			end
			
			# Extract the protocol list from the Rack environment.
			#
			# Checks both `rack.protocol` and {CGI::HTTP_UPGRADE} headers.
			# 
			# @parameter env [Hash] The Rack environment hash.
			# @returns [Array(String) | Nil] The list of protocols or `nil` if none specified.
			def self.protocol(env)
				if protocols = env["rack.protocol"]
					return Array(protocols)
				elsif protocols = env[CGI::HTTP_UPGRADE]
					return protocols.split(/\s*,\s*/)
				end
			end
			
			# Extract HTTP headers from the Rack environment.
			# Converts Rack's `HTTP_*` environment variables to proper HTTP headers.
			# 
			# @parameter env [Hash] The Rack environment hash.
			# @returns [Protocol::HTTP::Headers] The extracted HTTP headers.
			def self.headers(env)
				headers = ::Protocol::HTTP::Headers.new
				env.each do |key, value|
					if key.start_with?("HTTP_")
						next if key == "HTTP_HOST"
						headers[key[5..-1].gsub("_", "-").downcase] = value
					end
				end
				
				return headers
			end
		end
	end
end
