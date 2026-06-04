# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"

module Protocol
	module HTTP2
		ACKNOWLEDGEMENT = 0x1
		
		# Provides acknowledgement functionality for frames that support it.
		# This module handles setting and checking acknowledgement flags on frames.
		module Acknowledgement
			# Check if the frame is an acknowledgement.
			# @returns [Boolean] True if the acknowledgement flag is set.
			def acknowledgement?
				flag_set?(ACKNOWLEDGEMENT)
			end
			
			# Mark this frame as an acknowledgement.
			def acknowledgement!
				set_flags(ACKNOWLEDGEMENT)
			end
			
			# Create an acknowledgement frame for this frame.
			# @returns [Frame] A new frame marked as an acknowledgement.
			def acknowledge
				frame = self.class.new
				
				frame.length = 0
				frame.set_flags(ACKNOWLEDGEMENT)
				
				return frame
			end
		end
		
		# The PING frame is a mechanism for measuring a minimal round-trip time from the sender, as well as determining whether an idle connection is still functional. PING frames can be sent from any endpoint.
		#
		# +---------------------------------------------------------------+
		# |                                                               |
		# |                      Opaque Data (64)                         |
		# |                                                               |
		# +---------------------------------------------------------------+
		#
		class PingFrame < Frame
			TYPE = 0x6
			
			include Acknowledgement
			
			# Check if this frame applies to the connection level.
			# @returns [Boolean] Always returns true for PING frames.
			def connection?
				true
			end
			
			# Apply this PING frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_ping(self)
			end
			
			# Create an acknowledgement PING frame with the same payload.
			# @returns [PingFrame] A new PING frame marked as an acknowledgement.
			def acknowledge
				frame = super
				
				frame.pack self.unpack
				
				return frame
			end
			
			# Read and validate the PING frame payload.
			# @parameter stream [IO] The stream to read from.
			# @raises [ProtocolError] If validation fails.
			def read_payload(stream)
				super
				
				if @stream_id != 0
					raise ProtocolError, "Settings apply to connection only, but stream_id was given"
				end
				
				if @length != 8
					raise FrameSizeError, "Invalid frame length: #{@length} != 8!"
				end
			end
		end
	end
end
