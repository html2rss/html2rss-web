# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

module Protocol
	module Rack
		# Used for injecting the raw request into the Rack environment.
		PROTOCOL_HTTP_REQUEST = "protocol.http.request"
		
		# CGI environment variable keys as defined in [RFC 3875](https://tools.ietf.org/html/rfc3875#section-4.1).
		module CGI
			HTTP_HOST = "HTTP_HOST"
			HTTP_UPGRADE = "HTTP_UPGRADE"
			PATH_INFO = "PATH_INFO"
			REQUEST_METHOD = "REQUEST_METHOD"
			REQUEST_PATH = "REQUEST_PATH"
			REQUEST_URI = "REQUEST_URI"
			SCRIPT_NAME = "SCRIPT_NAME"
			QUERY_STRING = "QUERY_STRING"
			SERVER_PROTOCOL = "SERVER_PROTOCOL"
			SERVER_NAME = "SERVER_NAME"
			SERVER_PORT = "SERVER_PORT"
			REMOTE_ADDR = "REMOTE_ADDR"
			CONTENT_TYPE = "CONTENT_TYPE"
			CONTENT_LENGTH = "CONTENT_LENGTH"
			
			HTTP_COOKIE = "HTTP_COOKIE"
			
			# Additional HTTP header constants.
			HTTP_X_FORWARDED_PROTO = "HTTP_X_FORWARDED_PROTO"
		end
		
		# Rack environment variable keys.
		RACK_ERRORS = "rack.errors"
		RACK_LOGGER = "rack.logger"
		RACK_INPUT = "rack.input"
		RACK_URL_SCHEME = "rack.url_scheme"
		RACK_PROTOCOL = "rack.protocol"
		RACK_RESPONSE_FINISHED = "rack.response_finished"
		
		# Rack hijack support keys.
		RACK_IS_HIJACK = "rack.hijack?"
		RACK_HIJACK = "rack.hijack"
	end
end
