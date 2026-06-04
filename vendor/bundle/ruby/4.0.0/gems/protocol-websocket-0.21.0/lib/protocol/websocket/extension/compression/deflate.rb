# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require_relative "constants"

module Protocol
	module WebSocket
		module Extension
			module Compression
				# Compresses outgoing WebSocket frames using the DEFLATE algorithm.
				class Deflate
					# Client writing to server.
					def self.client(parent, client_max_window_bits: 15, client_no_context_takeover: false, **options)
						self.new(parent,
							window_bits: client_max_window_bits,
							context_takeover: !client_no_context_takeover,
							**options
						)
					end
					
					# Server writing to client.
					def self.server(parent, server_max_window_bits: 15, server_no_context_takeover: false, **options)
						self.new(parent,
							window_bits: server_max_window_bits,
							context_takeover: !server_no_context_takeover,
							**options
						)
					end
					
					# Initialize a new deflate compressor.
					# @parameter parent [Object] The parent framer to wrap.
					# @parameter level [Integer] The compression level. Defaults to `Zlib::DEFAULT_COMPRESSION`.
					# @parameter memory_level [Integer] The memory level for compression. Defaults to `Zlib::DEF_MEM_LEVEL`.
					# @parameter strategy [Integer] The compression strategy. Defaults to `Zlib::DEFAULT_STRATEGY`.
					# @parameter window_bits [Integer] The window size in bits for the DEFLATE algorithm.
					# @parameter context_takeover [Boolean] Whether to reuse the compression context across messages.
					def initialize(parent, level: Zlib::DEFAULT_COMPRESSION, memory_level: Zlib::DEF_MEM_LEVEL, strategy: Zlib::DEFAULT_STRATEGY, window_bits: 15, context_takeover: true, **options)
						@parent = parent
						
						@deflate = nil
						
						@level = level
						@memory_level = memory_level
						@strategy = strategy
						
						# This is handled during negotiation:
						# if window_bits < MINIMUM_WINDOW_BITS
						# 	window_bits = MINIMUM_WINDOW_BITS
						# end
						
						@window_bits = window_bits
						@context_takeover = context_takeover
					end
					
					# @returns [String] A string representation including window bits and context takeover settings.
					def to_s
						"#<#{self.class} window_bits=#{@window_bits} context_takeover=#{@context_takeover}>"
					end
					
					# @attribute [Integer] The window size in bits used for compression.
					attr :window_bits
					# @attribute [Boolean] Whether the compression context is reused across messages.
					attr :context_takeover
					
					# Pack a text frame, optionally compressing the buffer.
					# @parameter buffer [String] The text payload to pack.
					# @parameter compress [Boolean] Whether to compress the buffer. Defaults to `true`.
					# @returns [Frame] The packed (and optionally compressed) text frame.
					def pack_text_frame(buffer, compress: true, **options)
						if compress
							buffer = self.deflate(buffer)
						end
						
						frame = @parent.pack_text_frame(buffer, **options)
						
						if compress
							frame.flags |= Frame::RSV1
						end
						
						return frame
					end
					
					# Pack a binary frame, optionally compressing the buffer.
					# @parameter buffer [String] The binary payload to pack.
					# @parameter compress [Boolean] Whether to compress the buffer. Defaults to `false`.
					# @returns [Frame] The packed (and optionally compressed) binary frame.
					def pack_binary_frame(buffer, compress: false, **options)
						if compress
							buffer = self.deflate(buffer)
						end
						
						frame = @parent.pack_binary_frame(buffer, **options)
						
						if compress
							frame.flags |= Frame::RSV1
						end
						
						return frame
					end
					
					private
					
					def deflate(buffer)
						deflate = @deflate || Zlib::Deflate.new(@level, -@window_bits, @memory_level, @strategy)
						
						if @context_takeover
							@deflate = deflate
						end
						
						return deflate.deflate(buffer, Zlib::SYNC_FLUSH)[0...-4]
					end
				end
			end
		end
	end
end
