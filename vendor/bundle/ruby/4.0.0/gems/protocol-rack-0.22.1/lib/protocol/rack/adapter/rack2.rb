# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.
# Copyright, 2025, by Francisco Mejia.

require "console"

require_relative "generic"
require_relative "../rewindable"

module Protocol
	module Rack
		module Adapter
			# The Rack 2 adapter provides compatibility with Rack 2.x applications.
			# It handles the conversion between {Protocol::HTTP} and Rack 2 environments.
			class Rack2 < Generic
				# The Rack version constant.
				RACK_VERSION = "rack.version"
				# Whether the application is multithreaded.
				RACK_MULTITHREAD = "rack.multithread"
				# Whether the application is multiprocess.
				RACK_MULTIPROCESS = "rack.multiprocess"
				# Whether the application should run only once.
				RACK_RUN_ONCE = "rack.run_once"
				
				# Create a Rack 2 environment hash for the request.
				# Sets up all required Rack 2 environment variables and processes the request.
				# 
				# @parameter request [Protocol::HTTP::Request] The incoming request.
				# @returns [Hash] The Rack 2 environment hash.
				def make_environment(request)
					request_path, query_string = request.path.split("?", 2)
					server_name, server_port = (request.authority || "").split(":", 2)
					
					env = {
						RACK_VERSION => [2, 0],
						RACK_MULTITHREAD => false,
						RACK_MULTIPROCESS => true,
						RACK_RUN_ONCE => false,
						
						PROTOCOL_HTTP_REQUEST => request,
						
						RACK_INPUT => Input.new(request.body),
						RACK_ERRORS => $stderr,
						RACK_LOGGER => self.logger,
						
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
				
				# Build a Rack `env` from the incoming request and apply it to the Rack middleware.
				#
				# @parameter request [Protocol::HTTP::Request] The incoming request.
				# @returns [Protocol::HTTP::Response] The HTTP response.
				# @raises [ArgumentError] If the status is not an integer or headers are nil.
				def call(request)
					env = self.make_environment(request)
					
					status, headers, body = @app.call(env)
					
					if status
						status = status.to_i
					else
						raise ArgumentError, "Status must be an integer!"
					end
					
					unless headers
						raise ArgumentError, "Headers must not be nil!"
					end
					
					# unless body.respond_to?(:each)
					# 	raise ArgumentError, "Body must respond to #each!"
					# end
					
					headers, meta = self.wrap_headers(headers)
					
					# Rack 2 spec does not allow only partial hijacking:
					# if hijack_body = meta[RACK_HIJACK]
					# 	body = hijack_body
					# end
					
					return Response.wrap(env, status, headers, meta, body, request)
				rescue => error
					return self.handle_error(env, status, headers, body, error)
				end
				
				# Process the Rack response headers into a {Protocol::HTTP::Headers} instance, along with any extra `rack.` metadata.
				# Headers with newline-separated values are split into multiple headers.
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
						elsif value.is_a?(String)
							value.split("\n").each do |value|
								headers.add(key, value)
							end
						else
							headers.add(key, value)
						end
					end
					
					return headers, meta
				end
				
				# Convert a {Protocol::HTTP::Response} into a Rack 2 response tuple.
				# Handles protocol upgrades and streaming responses.
				# 
				# @parameter env [Hash] The Rack environment.
				# @parameter response [Protocol::HTTP::Response] The HTTP response.
				# @returns [Tuple(Integer, Hash, Object)] The Rack 2 response tuple `[status, headers, body]`.
				def self.make_response(env, response)
					# These interfaces should be largely compatible:
					headers = response.headers.to_h
					
					self.extract_protocol(env, response, headers)
					
					if body = response.body and body.stream?
						if env[RACK_IS_HIJACK]
							headers[RACK_HIJACK] = body
							body = []
						end
					end
					
					headers.transform_values! do |value|
						if value.is_a?(Array)
							value.join("\n")
						else
							value
						end
					end
					
					[response.status, headers, body]
				end
			end
		end
	end
end
