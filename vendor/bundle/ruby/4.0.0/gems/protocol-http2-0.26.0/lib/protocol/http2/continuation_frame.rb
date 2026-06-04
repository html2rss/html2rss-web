# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "frame"

module Protocol
	module HTTP2
		# Module for frames that can be continued with CONTINUATION frames.
		module Continued
			# @constant [Integer] The maximum number of continuation frames to read to prevent resource exhaustion.
			LIMIT = 8
			
			# Initialize a continuable frame.
			# @parameter arguments [Array] Arguments passed to parent constructor.
			def initialize(*)
				super
				
				@continuation = nil
			end
			
			# Check if this frame has continuation frames.
			# @returns [Boolean] True if there are continuation frames.
			def continued?
				!!@continuation
			end
			
			# Check if this is the last header block fragment.
			# @returns [Boolean] True if the END_HEADERS flag is set.
			def end_headers?
				flag_set?(END_HEADERS)
			end
			
			# Read the frame and any continuation frames from the stream.
			#
			# There is an upper limit to the number of continuation frames that can be read to prevent resource exhaustion. If the limit is 0, only one frame will be read (the initial frame). Otherwise, the limit decrements with each continuation frame read.
			#
			# @parameter stream [IO] The stream to read from.
			# @parameter maximum_frame_size [Integer] Maximum allowed frame size.
			# @parameter limit [Integer] The maximum number of continuation frames to read.
			def read(stream, maximum_frame_size, limit = LIMIT)
				super(stream, maximum_frame_size)
				
				unless end_headers?
					if limit.zero?
						raise ProtocolError, "Too many continuation frames!"
					end
					
					continuation = ContinuationFrame.new
					continuation.read_header(stream)
					
					# We validate the frame type here:
					unless continuation.valid_type?
						raise ProtocolError, "Invalid frame type: #{@type}!"
					end
					
					if continuation.stream_id != @stream_id
						raise ProtocolError, "Invalid stream id: #{continuation.stream_id} for continuation of stream id: #{@stream_id}!"
					end
					
					continuation.read(stream, maximum_frame_size, limit - 1)
					
					@continuation = continuation
				end
			end
			
			# Write the frame and any continuation frames to the stream.
			# @parameter stream [IO] The stream to write to.
			def write(stream)
				super
				
				if continuation = self.continuation
					continuation.write(stream)
				end
			end
			
			attr_accessor :continuation
			
			# Pack data into this frame, creating continuation frames if needed.
			# @parameter data [String] The data to pack.
			# @parameter options [Hash] Options including maximum_size.
			def pack(data, **options)
				maximum_size = options[:maximum_size]
				
				if maximum_size and data.bytesize > maximum_size
					clear_flags(END_HEADERS)
					
					super(data.byteslice(0, maximum_size), **options)
					
					remainder = data.byteslice(maximum_size, data.bytesize-maximum_size)
					
					@continuation = ContinuationFrame.new
					@continuation.pack(remainder, maximum_size: maximum_size)
				else
					set_flags(END_HEADERS)
					
					super data, **options
					
					@continuation = nil
				end
			end
			
			# Unpack data from this frame and any continuation frames.
			# @returns [String] The complete unpacked data.
			def unpack
				if @continuation.nil?
					super
				else
					super + @continuation.unpack
				end
			end
		end
		
		# The CONTINUATION frame is used to continue a sequence of header block fragments. Any number of CONTINUATION frames can be sent, as long as the preceding frame is on the same stream and is a HEADERS, PUSH_PROMISE, or CONTINUATION frame without the END_HEADERS flag set.
		#
		# +---------------------------------------------------------------+
		# |                   Header Block Fragment (*)                 ...
		# +---------------------------------------------------------------+
		#
		class ContinuationFrame < Frame
			include Continued
			
			TYPE = 0x9
			
			# Read the frame and any continuation frames from the stream.
			# @parameter stream [IO] The stream to read from.
			# @parameter maximum_frame_size [Integer] Maximum allowed frame size.
			# @parameter limit [Integer] The maximum number of continuation frames to read.
			def read(stream, maximum_frame_size, limit = 8)
				super
			end
			
			# This is only invoked if the continuation is received out of the normal flow.
			def apply(connection)
				connection.receive_continuation(self)
			end
			
			# Get a string representation of the continuation frame.
			# @returns [String] Human-readable frame information.
			def inspect
				"\#<#{self.class} stream_id=#{@stream_id} flags=#{@flags} length=#{@length || 0}b>"
			end
		end
	end
end
