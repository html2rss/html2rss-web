# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.
# Copyright, 2025, by Francisco Mejia.

require "console"

require_relative "rack3"

module Protocol
	module Rack
		module Adapter
			# The Rack 3.1 adapter provides compatibility with Rack 3.1.x applications.
			# It extends the Rack 3 adapter with improved request body handling and protocol support.
			# Key improvements include:
			# - Better handling of empty request bodies
			# - Direct protocol support via {RACK_PROTOCOL}
			# - More efficient body streaming
			class Rack31 < Rack3
				# Create a Rack 3.1 environment hash for the request.
				# Sets up all required Rack 3.1 environment variables and processes the request.
				# Unlike Rack 3, this adapter has improved body handling and protocol support.
				# 
				# @parameter request [Protocol::HTTP::Request] The incoming request.
				# @returns [Hash] The Rack 3.1 environment hash.
				def make_environment(request)
					request_path, query_string = request.path.split("?", 2)
					server_name, server_port = (request.authority || "").split(":", 2)
					
					env = {
						PROTOCOL_HTTP_REQUEST => request,
						
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
					
					# The request protocol, either from the upgrade header or the HTTP/2 pseudo header of the same name.
					if protocol = request.protocol
						env[RACK_PROTOCOL] = protocol
					end
					
					if body = request.body
						if body.empty?
							body.close
						else
							env[RACK_INPUT] = Input.new(body)
						end
					end
					
					self.unwrap_request(request, env)
					
					return env
				end
			end
		end
	end
end
