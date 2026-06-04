# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.
# Copyright, 2025, by Francisco Mejia.

require "console"

require_relative "generic"

module Protocol
	module Rack
		module Adapter
			# The Rack 3 adapter provides compatibility with Rack 3.x applications.
			# It handles the conversion between {Protocol::HTTP} and Rack 3 environments.
			# Unlike Rack 2, this adapter supports streaming responses and has a simpler environment setup.
			class Rack3 < Generic
				# Creates a new adapter instance for the given Rack application.
				# Unlike Rack 2, this adapter doesn't require a {Rewindable} wrapper.
				# 
				# @parameter app [Interface(:call)] A Rack application.
				# @returns [Rack3] A new adapter instance.
				def self.wrap(app)
					self.new(app)
				end
				
				# Parses a Rackup file and returns the application.
				# Uses the Rack 3.x interface for parsing Rackup files.
				# 
				# @parameter path [String] The path to the Rackup file.
				# @returns [Interface(:call)] The Rack application.
				def self.parse_file(...)
					::Rack::Builder.parse_file(...)
				end
				
				# Create a Rack 3 environment hash for the request.
				# Sets up all required Rack 3 environment variables and processes the request.
				# Unlike Rack 2, this adapter doesn't set Rack version or threading flags.
				# 
				# @parameter request [Protocol::HTTP::Request] The incoming request.
				# @returns [Hash] The Rack 3 environment hash.
				def make_environment(request)
					request_path, query_string = request.path.split("?", 2)
					server_name, server_port = (request.authority || "").split(":", 2)
					
					env = {
						PROTOCOL_HTTP_REQUEST => request,
						
						RACK_INPUT => Input.new(request.body),
						RACK_ERRORS => $stderr,
						RACK_LOGGER => self.logger,
						
						# The response finished callbacks:
						RACK_RESPONSE_FINISHED => [],
						
						# The HTTP request method, such as "GET" or "POST". This cannot ever be an empty string, and so is always required.
						CGI::REQUEST_METHOD => request.method,
						
						# The initial portion of the request URL's "path" that corresponds to the application object, so that the application knows its virtual "location". This may be an empty string, if the application corresponds to the "root" of the server.
						CGI::SCRIPT_NAME => "",
						
						# The remainder of the request URL's "path", designating the virtual "location" of the request's target within the application. This may be an empty string, if the request URL targets the application root and does not have a trailing slash. This value may be percent-encoded when originating from a URL.
						CGI::PATH_INFO => request_path,
						CGI::REQUEST_PATH => request_path,
						CGI::REQUEST_URI => request.path,
						
						# The portion of the request URL that follows the ?, if any. May be empty, but is always required!
						CGI::QUERY_STRING => query_string || "",
						
						# The server protocol (e.g. HTTP/1.1):
						CGI::SERVER_PROTOCOL => request.version,
						
						# The request scheme:
						RACK_URL_SCHEME => request.scheme,
						
						# I'm not sure what sane defaults should be here:
						CGI::SERVER_NAME => server_name,
					}
					
					# SERVER_PORT is optional but must not be set if it is not present.
					if server_port
						env[CGI::SERVER_PORT] = server_port
					end
					
					self.unwrap_request(request, env)
					
					return env
				end
				
				# Process the rack response headers into a {Protocol::HTTP::Headers} instance, along with any extra `rack.` metadata.
				# Unlike Rack 2, this adapter handles array values directly without splitting on newlines.
				# 
				# @parameter fields [Hash] The raw response headers.
				# @returns [Tuple(Protocol::HTTP::Headers, Hash)] The processed headers and metadata.
				def wrap_headers(fields)
					headers = ::Protocol::HTTP::Headers.new
					meta = {}
					
					fields.each do |key, value|
						key = key.downcase
						
						if key.start_with?("rack.")
							meta[key] = value
						elsif value.is_a?(Array)
							value.each do |value|
								headers.add(key, value)
							end
						else
							headers.add(key, value)
						end
					end
					
					return headers, meta
				end
				
				# Convert a {Protocol::HTTP::Response} into a Rack 3 response tuple.
				# Handles protocol upgrades and streaming responses.
				# Unlike Rack 2, this adapter forces streaming responses by converting the body to a callable.
				# 
				# @parameter env [Hash] The Rack environment.
				# @parameter response [Protocol::HTTP::Response] The HTTP response.
				# @returns [Tuple(Integer, Hash, Object)] The Rack 3 response tuple `[status, headers, body]`.
				def self.make_response(env, response)
					# These interfaces should be largely compatible:
					headers = response.headers.to_h
					
					self.extract_protocol(env, response, headers)
					
					if body = response.body and body.stream?
						# Force streaming response:
						body = body.method(:call)
					end
					
					[response.status, headers, body]
				end
			end
		end
	end
end
