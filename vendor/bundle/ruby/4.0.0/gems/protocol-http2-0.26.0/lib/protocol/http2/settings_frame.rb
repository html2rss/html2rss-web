# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "ping_frame"

module Protocol
	module HTTP2
		# HTTP/2 connection settings container and management.
		class Settings
			HEADER_TABLE_SIZE = 0x1
			ENABLE_PUSH = 0x2
			MAXIMUM_CONCURRENT_STREAMS = 0x3
			INITIAL_WINDOW_SIZE = 0x4
			MAXIMUM_FRAME_SIZE = 0x5
			MAXIMUM_HEADER_LIST_SIZE = 0x6
			ENABLE_CONNECT_PROTOCOL = 0x8
			NO_RFC7540_PRIORITIES = 0x9
			
			ASSIGN = [
				nil,
				:header_table_size=,
				:enable_push=,
				:maximum_concurrent_streams=,
				:initial_window_size=,
				:maximum_frame_size=,
				:maximum_header_list_size=,
				nil,
				:enable_connect_protocol=,
				:no_rfc7540_priorities=,
			]
			
			# Initialize settings with default values from HTTP/2 specification.
			def initialize
				# These limits are taken from the RFC:
				# https://tools.ietf.org/html/rfc7540#section-6.5.2
				@header_table_size = 4096
				@enable_push = 1
				@maximum_concurrent_streams = 0xFFFFFFFF
				@initial_window_size = 0xFFFF # 2**16 - 1
				@maximum_frame_size = 0x4000 # 2**14
				@maximum_header_list_size = 0xFFFFFFFF
				@enable_connect_protocol = 0
				@no_rfc7540_priorities = 0
			end
			
			# Allows the sender to inform the remote endpoint of the maximum size of the header compression table used to decode header blocks, in octets.
			attr_accessor :header_table_size
			
			# This setting can be used to disable server push. An endpoint MUST NOT send a PUSH_PROMISE frame if it receives this parameter set to a value of 0.
			attr :enable_push
			
			# Set the server push enable flag.
			# @parameter value [Integer] Must be 0 (disabled) or 1 (enabled).
			# @raises [ProtocolError] If the value is invalid.
			def enable_push= value
				if value == 0 or value == 1
					@enable_push = value
				else
					raise ProtocolError, "Invalid value for enable_push: #{value}"
				end
			end
			
			# Check if server push is enabled.
			# @returns [Boolean] True if server push is enabled.
			def enable_push?
				@enable_push == 1
			end
			
			# Indicates the maximum number of concurrent streams that the sender will allow.
			attr_accessor :maximum_concurrent_streams
			
			# Indicates the sender's initial window size (in octets) for stream-level flow control.
			attr :initial_window_size
			
			# Set the initial window size for stream-level flow control.
			# @parameter value [Integer] The window size in octets.
			# @raises [ProtocolError] If the value exceeds the maximum allowed.
			def initial_window_size= value
				if value <= MAXIMUM_ALLOWED_WINDOW_SIZE
					@initial_window_size = value
				else
					raise ProtocolError, "Invalid value for initial_window_size: #{value} > #{MAXIMUM_ALLOWED_WINDOW_SIZE}"
				end
			end
			
			# Indicates the size of the largest frame payload that the sender is willing to receive, in octets.
			attr :maximum_frame_size
			
			# Set the maximum frame size the sender is willing to receive.
			# @parameter value [Integer] The maximum frame size in octets.
			# @raises [ProtocolError] If the value is outside the allowed range.
			def maximum_frame_size= value
				if value > MAXIMUM_ALLOWED_FRAME_SIZE
					raise ProtocolError, "Invalid value for maximum_frame_size: #{value} > #{MAXIMUM_ALLOWED_FRAME_SIZE}"
				elsif value < MINIMUM_ALLOWED_FRAME_SIZE
					raise ProtocolError, "Invalid value for maximum_frame_size: #{value} < #{MINIMUM_ALLOWED_FRAME_SIZE}"
				else
					@maximum_frame_size = value
				end
			end
			
			# This advisory setting informs a peer of the maximum size of header list that the sender is prepared to accept, in octets.
			attr_accessor :maximum_header_list_size
			
			attr :enable_connect_protocol
			
			# Set the CONNECT protocol enable flag.
			# @parameter value [Integer] Must be 0 (disabled) or 1 (enabled).
			# @raises [ProtocolError] If the value is invalid.
			def enable_connect_protocol= value
				if value == 0 or value == 1
					@enable_connect_protocol = value
				else
					raise ProtocolError, "Invalid value for enable_connect_protocol: #{value}"
				end
			end
			
			# Check if CONNECT protocol is enabled.
			# @returns [Boolean] True if CONNECT protocol is enabled.
			def enable_connect_protocol?
				@enable_connect_protocol == 1
			end
			
			attr :no_rfc7540_priorities
			
			# Set the RFC 7540 priorities disable flag.
			# @parameter value [Integer] Must be 0 (enabled) or 1 (disabled).
			# @raises [ProtocolError] If the value is invalid.
			def no_rfc7540_priorities= value
				if value == 0 or value == 1
					@no_rfc7540_priorities = value
				else
					raise ProtocolError, "Invalid value for no_rfc7540_priorities: #{value}"
				end
			end
			
			# Check if RFC 7540 priorities are disabled.
			# @returns [Boolean] True if RFC 7540 priorities are disabled.
			def no_rfc7540_priorities?
				@no_rfc7540_priorities == 1
			end
			
			# Update settings with a hash of changes.
			# @parameter changes [Hash] Hash of setting keys and values to update.
			def update(changes)
				changes.each do |key, value|
					if name = ASSIGN[key]
						self.send(name, value)
					end
				end
			end
		end
		
		# Manages pending settings changes that haven't been acknowledged yet.
		class PendingSettings
			# Initialize with current settings.
			# @parameter current [Settings] The current settings object.
			def initialize(current = Settings.new)
				@current = current
				@pending = current.dup
				
				@queue = []
			end
			
			attr :current
			attr :pending
			
			# Append changes to the pending queue.
			# @parameter changes [Hash] Hash of setting changes to queue.
			def append(changes)
				@queue << changes
				@pending.update(changes)
			end
			
			# Acknowledge the next set of pending changes.
			def acknowledge
				if changes = @queue.shift
					@current.update(changes)
					
					return changes
				else
					raise ProtocolError, "Cannot acknowledge settings, no changes pending"
				end
			end
			
			# Get the current header table size setting.
			# @returns [Integer] The header table size in octets.
			def header_table_size
				@current.header_table_size
			end
			
			# Get the current enable push setting.
			# @returns [Integer] 1 if push is enabled, 0 if disabled.
			def enable_push
				@current.enable_push
			end
			
			# Get the current maximum concurrent streams setting.
			# @returns [Integer] The maximum number of concurrent streams.
			def maximum_concurrent_streams
				@current.maximum_concurrent_streams
			end
			
			# Get the current initial window size setting.
			# @returns [Integer] The initial window size in octets.
			def initial_window_size
				@current.initial_window_size
			end
			
			# Get the current maximum frame size setting.
			# @returns [Integer] The maximum frame size in octets.
			def maximum_frame_size
				@current.maximum_frame_size
			end
			
			# Get the current maximum header list size setting.
			# @returns [Integer] The maximum header list size in octets.
			def maximum_header_list_size
				@current.maximum_header_list_size
			end
			
			# Get the current CONNECT protocol enable setting.
			# @returns [Integer] 1 if CONNECT protocol is enabled, 0 if disabled.
			def enable_connect_protocol
				@current.enable_connect_protocol
			end
		end
		
		# The SETTINGS frame conveys configuration parameters that affect how endpoints communicate, such as preferences and constraints on peer behavior. The SETTINGS frame is also used to acknowledge the receipt of those parameters. Individually, a SETTINGS parameter can also be referred to as a "setting".
		# 
		# +-------------------------------+
		# |       Identifier (16)         |
		# +-------------------------------+-------------------------------+
		# |                        Value (32)                             |
		# +---------------------------------------------------------------+
		#
		class SettingsFrame < Frame
			TYPE = 0x4
			FORMAT = "nN".freeze
			
			include Acknowledgement
			
			# Check if this frame applies to the connection level.
			# @returns [Boolean] Always returns true for SETTINGS frames.
			def connection?
				true
			end
			
			# Unpack settings parameters from the frame payload.
			# @returns [Array] Array of [key, value] pairs representing settings.
			def unpack
				if buffer = super
					# TODO String#each_slice, or #each_unpack would be nice.
					buffer.scan(/....../m).map{|s| s.unpack(FORMAT)}
				else
					[]
				end
			end
			
			# Pack settings parameters into the frame payload.
			# @parameter settings [Array] Array of [key, value] pairs to pack.
			def pack(settings = [])
				super(settings.map{|s| s.pack(FORMAT)}.join)
			end
			
			# Apply this SETTINGS frame to a connection for processing.
			# @parameter connection [Connection] The connection to apply the frame to.
			def apply(connection)
				connection.receive_settings(self)
			end
			
			# Read and validate the SETTINGS frame payload.
			# @parameter stream [IO] The stream to read from.
			# @raises [ProtocolError] If the frame is invalid.
			# @raises [FrameSizeError] If the frame length is invalid.
			def read_payload(stream)
				super
				
				if @stream_id != 0
					raise ProtocolError, "Settings apply to connection only, but stream_id was given"
				end
				
				if acknowledgement? and @length != 0
					raise FrameSizeError, "Settings acknowledgement must not contain payload: #{@payload.inspect}"
				end
				
				if (@length % 6) != 0
					raise FrameSizeError, "Invalid frame length"
				end
			end
		end
	end
end
