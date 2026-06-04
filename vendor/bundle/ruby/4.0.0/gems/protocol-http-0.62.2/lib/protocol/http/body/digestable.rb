# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "wrapper"

require "digest/sha2"

module Protocol
	module HTTP
		module Body
			# Invokes a callback once the body has finished reading.
			class Digestable < Wrapper
				# Wrap a message body with a callback. If the body is empty, the callback is not invoked, as there is no data to digest.
				#
				# @parameter message [Request | Response] the message body.
				# @parameter digest [Digest] the digest to use.
				# @parameter block [Proc] the callback to invoke when the body is closed.
				def self.wrap(message, digest = Digest::SHA256.new, &block)
					if body = message&.body and !body.empty?
						message.body = self.new(message.body, digest, block)
					end
				end
				
				# Initialize the digestable body with a callback.
				#
				# @parameter body [Readable] the body to wrap.
				# @parameter digest [Digest] the digest to use.
				# @parameter callback [Block] The callback is invoked when the digest is complete.
				def initialize(body, digest = Digest::SHA256.new, callback = nil)
					super(body)
					
					@digest = digest
					@callback = callback
				end
				
				# @attribute [Digest] digest the digest object.
				attr :digest
				
				# Generate an appropriate ETag for the digest, assuming it is complete. If you call this method before the body is fully read, the ETag will be incorrect.
				#
				# @parameter weak [Boolean] If true, the ETag is marked as weak.
				# @returns [String] the ETag.
				def etag(weak: false)
					if weak
						"W/\"#{digest.hexdigest}\""
					else
						"\"#{digest.hexdigest}\""
					end
				end
				
				# Read the body and update the digest. When the body is fully read, the callback is invoked with `self` as the argument.
				#
				# @returns [String | Nil] the next chunk of data, or nil if the body is fully read.
				def read
					if chunk = super
						@digest.update(chunk)
						
						return chunk
					else
						@callback&.call(self)
						
						return nil
					end
				end
				
				# Convert the body to a hash suitable for serialization.
				#
				# @returns [Hash] The body as a hash.
				def as_json(...)
					super.merge(
						digest_class: @digest.class.name,
						callback: @callback&.to_s
					)
				end
			end
		end
	end
end
