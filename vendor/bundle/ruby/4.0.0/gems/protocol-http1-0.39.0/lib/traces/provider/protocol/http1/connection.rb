# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../protocol/http1/connection"

Traces::Provider(Protocol::HTTP1::Connection) do
	def write_request(authority, method, target, version, headers)
		attributes = {
			authority: authority,
			method: method,
			target: target,
			version: version,
			headers: headers&.to_h,
		}
		
		Traces.trace("protocol.http1.connection.write_request", attributes: attributes) do
			super
		end
	end
	
	def write_response(version, status, headers, reason = nil)
		attributes = {
			version: version,
			status: status,
			headers: headers&.to_h,
		}
		
		Traces.trace("protocol.http1.connection.write_response", attributes: attributes) do
			super
		end
	end
	
	def write_interim_response(version, status, headers, reason = nil)
		attributes = {
			version: version,
			status: status,
			headers: headers&.to_h,
			reason: reason,
		}
		
		Traces.trace("protocol.http1.connection.write_interim_response", attributes: attributes) do
			super
		end
	end
	
	def write_body(version, body, head = false, trailer = nil)
		attributes = {
			version: version,
			head: head,
			trailer: trailer,
			body: body&.as_json,
		}
		
		Traces.trace("protocol.http1.connection.write_body", attributes: attributes) do |span|
			super
		rescue => error
			# Capture the body state at the time of the error for EPIPE debugging:
			span["error.body"] = body&.as_json
			span["error.connection"] = {
				state: @state,
				persistent: @persistent,
				count: @count,
				stream_closed: @stream.nil?
			}
			
			raise error
		end
	end
end
