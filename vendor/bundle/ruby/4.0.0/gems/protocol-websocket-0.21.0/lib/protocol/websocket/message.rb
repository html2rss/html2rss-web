# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require_relative "frame"
require_relative "coder"

module Protocol
	module WebSocket
		# Represents a message that can be sent or received over a WebSocket connection.
		class Message
			# Create a new message from a buffer.
			# @attribute buffer [String] The message buffer.
			def initialize(buffer = "")
				@buffer = buffer
			end
			
			# @attribute [String] The message buffer.
			attr :buffer
			
			# @returns [Integer] The size of the message buffer.
			def size
				@buffer.bytesize
			end
			
			# Compare this message to another message or buffer.
			def == other
				@buffer == other.to_str
			end
			
			# A message is implicitly convertible to it's buffer.
			def to_str
				@buffer
			end
			
			# The encoding of the message buffer.
			# @returns [Encoding]
			def encoding
				@buffer.encoding
			end
			
			# Generate a message from a value using the given coder.
			# @property value [Object] The value to encode.
			# @property coder [Coder] The coder to use. Defaults to JSON.
			def self.generate(value, coder = Coder::DEFAULT)
				new(coder.generate(value))
			end
			
			# Parse the message buffer using the given coder. Defaults to JSON.
			def parse(coder = Coder::DEFAULT)
				coder.parse(@buffer)
			end
			
			# Convert the message buffer to a hash using the given coder. Defaults to JSON.
			def to_h(...)
				parse(...).to_h
			end
			
			# Send this message as a text frame over the given connection.
			# @parameter connection [Connection] The WebSocket connection to send through.
			def send(connection, **options)
				connection.send_text(@buffer, **options)
			end
		end
		
		# Represents a text message that can be sent or received over a WebSocket connection.
		class TextMessage < Message
		end
		
		# Represents a binary message that can be sent or received over a WebSocket connection.
		class BinaryMessage < Message
			# Send this message as a binary frame over the given connection.
			# @parameter connection [Connection] The WebSocket connection to send through.
			def send(connection, **options)
				connection.send_binary(@buffer, **options)
			end
		end
		
		# Represents a ping message that can be sent over a WebSocket connection.
		class PingMessage < Message
			# Send this message as a ping frame over the given connection.
			# @parameter connection [Connection] The WebSocket connection to send through.
			def send(connection)
				connection.send_ping(@buffer)
			end
		end
	end
end
