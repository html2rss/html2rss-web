# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2026, by Samuel Williams.

require_relative "compression/constants"
require_relative "compression/inflate"
require_relative "compression/deflate"

module Protocol
	module WebSocket
		# @namespace
		module Extension
			# Provides support for the permessage-deflate extension.
			module Compression
				# Client offer to server, construct a list of requested compression parameters suitable for the `Sec-WebSocket-Extensions` header.
				# @returns [Array(String)] a list of compression parameters suitable to send to the server.
				def self.offer(client_max_window_bits: true, server_max_window_bits: true, client_no_context_takeover: false, server_no_context_takeover: false)
					
					header = [NAME]
					
					case client_max_window_bits
					when 8..15
						header << "client_max_window_bits=#{client_max_window_bits}"
					when true
						header << "client_max_window_bits"
					else
						raise ArgumentError, "Invalid local maximum window bits!"
					end
					
					if client_no_context_takeover
						header << "client_no_context_takeover"
					end
					
					case server_max_window_bits
					when 8..15
						header << "server_max_window_bits=#{server_max_window_bits}"
					when true
						# Default (unspecified) to the server maximum window bits.
					else
						raise ArgumentError, "Invalid remote maximum window bits!"
					end
					
					if server_no_context_takeover
						header << "server_no_context_takeover"
					end
					
					return header
				end
				
				# Negotiate on the server a response to client based on the incoming client offer.
				# @parameter options [Hash] a hash of options which are accepted by the server.
				# @returns [Array(String)] a list of compression parameters suitable to send back to the client.
				def self.negotiate(arguments, **options)
					header = [NAME]
					
					arguments.each do |key, value|
						case key
						when "server_no_context_takeover"
							options[:server_no_context_takeover] = true
							header << key
						when "client_no_context_takeover"
							options[:client_no_context_takeover] = true
							header << key
						when "server_max_window_bits"
							value = Integer(value || 15)
							value = MINIMUM_WINDOW_BITS if value < MINIMUM_WINDOW_BITS
							options[:server_max_window_bits] = value
							header << "server_max_window_bits=#{value}"
						when "client_max_window_bits"
							value = Integer(value || 15)
							value = MINIMUM_WINDOW_BITS if value < MINIMUM_WINDOW_BITS
							options[:client_max_window_bits] = value
							header << "client_max_window_bits=#{value}"
						else
							raise ArgumentError, "Unknown option: #{key}!"
						end
					end
					
					# The header which represents the final accepted/negotiated configuration.
					return header, options
				end
				
				# @parameter options [Hash] a hash of options which are accepted by the server.
				def self.server(connection, **options)
					connection.reserve!(Frame::RSV1)
					
					connection.reader = Inflate.server(connection.reader, **options)
					connection.writer = Deflate.server(connection.writer, **options)
				end
				
				# Accept on the client, the negotiated server response.
				# @parameter options [Hash] a hash of options which are accepted by the client.
				# @parameter arguments [Array(String)] a list of compression parameters as accepted/negotiated by the server.
				def self.accept(arguments, **options)
					arguments.each do |key, value|
						case key
						when "server_no_context_takeover"
							options[:server_no_context_takeover] = true
						when "client_no_context_takeover"
							options[:client_no_context_takeover] = true
						when "server_max_window_bits"
							options[:server_max_window_bits] = Integer(value || 15)
						when "client_max_window_bits"
							options[:client_max_window_bits] = Integer(value || 15)
						else
							raise ArgumentError, "Unknown option: #{key}!"
						end
					end
					
					return options
				end
				
				# @parameter options [Hash] a hash of options which are accepted by the client.
				def self.client(connection, **options)
					connection.reserve!(Frame::RSV1)
					
					connection.reader = Inflate.client(connection.reader, **options)
					connection.writer = Deflate.client(connection.writer, **options)
				end
			end
		end
	end
end
