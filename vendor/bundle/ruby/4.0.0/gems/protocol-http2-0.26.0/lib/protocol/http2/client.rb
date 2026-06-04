# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "connection"

module Protocol
	module HTTP2
		# Represents an HTTP/2 client connection.
		# Manages client-side protocol semantics including stream ID allocation,
		# connection preface handling, and push promise processing.
		class Client < Connection
			# Initialize a new HTTP/2 client connection.
			# @parameter framer [Framer] The frame handler for reading/writing HTTP/2 frames.
			def initialize(framer)
				super(framer, 1)
			end
			
			# Check if the given stream ID represents a locally-initiated stream.
			# Client streams have odd numbered IDs.
			# @parameter id [Integer] The stream ID to check.
			# @returns [bool] True if the stream ID is locally-initiated.
			def local_stream_id?(id)
				id.odd?
			end
			
			# Check if the given stream ID represents a remotely-initiated stream.
			# Server streams have even numbered IDs.
			# @parameter id [Integer] The stream ID to check.
			# @returns [bool] True if the stream ID is remotely-initiated.
			def remote_stream_id?(id)
				id.even?
			end
			
			# Check if the given stream ID is valid for remote initiation.
			# Server-initiated streams must have even numbered IDs.
			# @parameter stream_id [Integer] The stream ID to validate.
			# @returns [bool] True if the stream ID is valid for remote initiation.
			def valid_remote_stream_id?(stream_id)
				stream_id.even?
			end
			
			# Send the HTTP/2 connection preface and initial settings.
			# This must be called once when the connection is first established.
			# @parameter settings [Array] Optional settings to send with the connection preface.
			# @raises [ProtocolError] If called when not in the new state.
			# @yields Allows custom processing during preface exchange.
			def send_connection_preface(settings = [])
				if @state == :new
					@framer.write_connection_preface
					
					send_settings(settings)
					
					yield if block_given?
					
					read_frame do |frame|
						unless frame.is_a? SettingsFrame
							raise ProtocolError, "First frame must be #{SettingsFrame}, but got #{frame.class}"
						end
					end
				else
					raise ProtocolError, "Cannot send connection preface in state #{@state}"
				end
			end
			
			# Clients cannot create push promise streams.
			# @raises [ProtocolError] Always, as clients cannot initiate push promises.
			def create_push_promise_stream
				raise ProtocolError, "Cannot create push promises from client!"
			end
			
			# Process a push promise frame received from the server.
			# @parameter frame [PushPromiseFrame] The push promise frame to process.
			# @returns [Array(Stream, Hash) | Nil] The promised stream and request headers, or nil if no associated stream.
			def receive_push_promise(frame)
				if frame.stream_id == 0
					raise ProtocolError, "Cannot receive headers for stream 0!"
				end
				
				if stream = @streams[frame.stream_id]
					# This is almost certainly invalid:
					promised_stream, request_headers = stream.receive_push_promise(frame)
					
					return promised_stream, request_headers
				end
			end
		end
	end
end
