# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2023, by Bruno Sutic.

module Protocol
	module HTTP
		module Body
			# Represents a readable input streams.
			#
			# There are two major modes of operation:
			#
			# 1. Reading chunks using {read} (or {each}/{join}), until the body is empty, or
			# 2. Streaming chunks using {call}, which writes chunks to a provided output stream.
			#
			# In both cases, reading can fail, for example if the body represents a streaming upload, and the connection is lost. In this case, {read} will raise some kind of error, or the stream will be closed with an error.
			#
			# At any point, you can use {close} to close the stream and release any resources, or {discard} to read all remaining data without processing it which may allow the underlying connection to be reused (but can be slower).
			class Readable
				# Close the stream immediately. After invoking this method, the stream should be considered closed, and all internal resources should be released.
				#
				# If an error occured while handling the output, it can be passed as an argument. This may be propagated to the client, for example the client may be informed that the stream was not fully read correctly.
				#
				# Invoking {read} after {close} will return `nil`.
				#
				# @parameter error [Exception | Nil] The error that caused this stream to be closed, if any.
				def close(error = nil)
				end
				
				# Optimistically determine whether read (may) return any data.
				#
				# - If this returns true, then calling read will definitely return nil.
				# - If this returns false, then calling read may return nil.
				#
				# @return [Boolean] Whether the stream is empty.
				def empty?
					false
				end
				
				# Whether calling read will return a chunk of data without blocking. We prefer pessimistic implementation, and thus default to `false`.
				#
				# @return [Boolean] Whether the stream is ready (read will not block).
				def ready?
					false
				end
				
				# Whether the stream can be rewound using {rewind}.
				#
				# @return [Boolean] Whether the stream is rewindable.
				def rewindable?
					false
				end
				
				# Rewind the stream to the beginning.
				#
				# @returns [Boolean] Whether the stream was successfully rewound.
				def rewind
					false
				end
				
				# Return a buffered representation of this body.
				#
				# This method must return a buffered body if `#rewindable?`.
				#
				# @returns [Buffered | Nil] The buffered body.
				def buffered
					nil
				end
				
				# The total length of the body, if known.
				#
				# @returns [Integer | Nil] The total length of the body, or `nil` if the length is unknown.
				def length
					nil
				end
				
				# Read the next available chunk.
				#
				# @returns [String | Nil] The chunk of data, or `nil` if the stream has finished.
				# @raises [StandardError] If an error occurs while reading.
				def read
					nil
				end
				
				# Enumerate all chunks until finished, then invoke {close}.
				#
				# Closes the stream when finished or if an error occurs.
				#
				# @yields {|chunk| ...} The block to call with each chunk of data.
				# 	@parameter chunk [String | Nil] The chunk of data, or `nil` if the stream has finished.
				def each
					return to_enum unless block_given?
					
					begin
						while chunk = self.read
							yield chunk
						end
					rescue => error
						raise
					ensure
						self.close(error)
					end
				end
				
				# Read all remaining chunks into a single binary string using `#each`.
				#
				# @returns [String | Nil] The binary string containing all chunks of data, or `nil` if the stream has finished (or did not contain any data).
				def join
					buffer = String.new.force_encoding(Encoding::BINARY)
					
					self.each do |chunk|
						buffer << chunk
					end
					
					if buffer.empty?
						return nil
					else
						return buffer
					end
				end
				
				# Whether to prefer streaming the body using {call} rather than reading it using {read} or {each}.
				#
				# @returns [Boolean] Whether the body should be streamed.
				def stream?
					false
				end
				
				# Invoke the body with the given stream.
				#
				# The default implementation simply writes each chunk to the stream. If the body is not ready, it will be flushed after each chunk. Closes the stream when finished or if an error occurs.
				#
				# Write the body to the given stream.
				#
				# @parameter stream [IO | Object] An `IO`-like object that responds to `#read`, `#write` and `#flush`.
				# @returns [Boolean] Whether the ownership of the stream was transferred.
				def call(stream)
					self.each do |chunk|
						stream.write(chunk)
						
						# Flush the stream unless we are immediately expecting more data:
						unless self.ready?
							stream.flush
						end
					end
				ensure
					# TODO Should this invoke close_write(error) instead?
					stream.close
				end
				
				# Read all remaining chunks into a buffered body and close the underlying input.
				#
				# @returns [Buffered] The buffered body.
				def finish
					# Internally, this invokes `self.each` which then invokes `self.close`.
					Buffered.read(self)
				end
				
				# Discard the body as efficiently as possible.
				#
				# The default implementation simply reads all chunks until the body is empty.
				#
				# Useful for discarding the body when it is not needed, but preserving the underlying connection.
				def discard
					while chunk = self.read
					end
				end
				
				# Convert the body to a hash suitable for serialization. This won't include the contents of the body, but will include metadata such as the length, streamability, and readiness, etc.
				#
				# @returns [Hash] The body as a hash.
				def as_json(...)
					{
						class: self.class.name,
						length: self.length,
						stream: self.stream?,
						ready: self.ready?,
						empty: self.empty?
					}
				end
				
				# Convert the body to JSON.
				#
				# @returns [String] The body as JSON.
				def to_json(...)
					as_json.to_json(...)
				end
			end
		end
	end
end
