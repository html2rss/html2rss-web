# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require_relative "adapter/version"

module Protocol
	module Rack
		# The Rack adapter provides a bridge between Protocol::HTTP and Rack applications.
		# It automatically selects the appropriate implementation based on the installed Rack version.
		# 
		# ```ruby
		# app = ->(env) { [200, {"content-type" => "text/plain"}, ["Hello World"]] }
		# adapter = Protocol::Rack::Adapter.new(app)
		# response = adapter.call(request)
		# ```
		module Adapter
			if VERSION >= "3.1"
				require_relative "adapter/rack31"
				IMPLEMENTATION = Rack31
			elsif VERSION >= "3"
				require_relative "adapter/rack3"
				IMPLEMENTATION = Rack3
			else
				require_relative "adapter/rack2"
				IMPLEMENTATION = Rack2
			end
			
			# Creates a new adapter instance for the given Rack application.
			# 
			# @parameter app [Interface(:call)] A Rack application that responds to `call`.
			# @returns [Protocol::HTTP::Middleware] An adapter that can handle HTTP requests.
			def self.new(app)
				IMPLEMENTATION.wrap(app)
			end
			
			# Converts a Rack response into a {Protocol::HTTP::Response}.
			# 
			# @parameter env [Hash] The Rack environment.
			# @parameter response [Array] The Rack response tuple `[status, headers, body]`.
			# @returns [Protocol::HTTP::Response] A Protocol::HTTP response.
			def self.make_response(env, response)
				IMPLEMENTATION.make_response(env, response)
			end
			
			# Parses a Rackup file and returns the application.
			# 
			# @parameter path [String] The path to the Rackup file.
			# @returns [Interface(:call)] The parsed Rack application.
			def self.parse_file(...)
				IMPLEMENTATION.parse_file(...)
			end
		end
	end
end
