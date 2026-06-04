# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "connection"

module Protocol
	module HTTP2
		# Represents an HTTP/2 server connection.
		# Manages server-side protocol semantics including stream ID allocation,
		# connection preface handling, and settings negotiation.
		class Server < Connection
			# Initialize a new HTTP/2 server connection.
			# @parameter framer [Framer] The frame handler for reading/writing HTTP/2 frames.
			def initialize(framer)
				super(framer, 2)
			end
			
			# Check if the given stream ID represents a locally-initiated stream.
			# Server streams have even numbered IDs.
			# @parameter id [Integer] The stream ID to check.
			# @returns [Boolean] True if the stream ID is locally-initiated.
			def local_stream_id?(id)
				id.even?
			end
			
			# Check if the given stream ID represents a remotely-initiated stream.
			# Client streams have odd numbered IDs.
			# @parameter id [Integer] The stream ID to check.
			# @returns [Boolean] True if the stream ID is remotely-initiated.
			def remote_stream_id?(id)
				id.odd?
			end
			
			# Check if the given stream ID is valid for remote initiation.
			# Client-initiated streams must have odd numbered IDs.
			# @parameter stream_id [Integer] The stream ID to validate.
			# @returns [Boolean] True if the stream ID is valid for remote initiation.
			def valid_remote_stream_id?(stream_id)
				stream_id.odd?
			end
			
			# Read the HTTP/2 connection preface from the client and send initial settings.
			# This must be called once when the connection is first established.
			# @parameter settings [Array] Optional settings to send during preface exchange.
			# @raises [ProtocolError] If called when not in the new state or preface is invalid.
			def read_connection_preface(settings = [])
				if @state == :new
					@framer.read_connection_preface
					
					send_settings(settings)
					
					read_frame do |frame|
						unless frame.is_a? SettingsFrame
							raise ProtocolError, "First frame must be #{SettingsFrame}, but got #{frame.class}"
						end
					end
				else
					raise ProtocolError, "Cannot read connection preface in state #{@state}"
				end
			end
			
			# Servers cannot accept push promise streams from clients.
			# @parameter stream_id [Integer] The stream ID (unused).
			# @raises [ProtocolError] Always, as servers cannot accept push promises.
			def accept_push_promise_stream(stream_id, &block)
				raise ProtocolError, "Cannot accept push promises on server!"
			end
			
			# Check if server push is enabled by the client.
			# @returns [Boolean] True if push promises are enabled.
			def enable_push?
				@remote_settings.enable_push?
			end
		end
	end
end
