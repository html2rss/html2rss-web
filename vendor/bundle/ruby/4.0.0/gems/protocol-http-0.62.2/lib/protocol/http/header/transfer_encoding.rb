# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# The `transfer-encoding` header indicates the encoding transformations that have been applied to the message body.
			#
			# The `transfer-encoding` header is used to specify the form of encoding used to safely transfer the message body between the sender and receiver.
			class TransferEncoding < Split
				# The `chunked` transfer encoding allows a server to send data of unknown length by breaking it into chunks.
				CHUNKED = "chunked"
				
				# The `gzip` transfer encoding compresses the message body using the gzip algorithm.
				GZIP = "gzip"
				
				# The `deflate` transfer encoding compresses the message body using the deflate algorithm.
				DEFLATE = "deflate"
				
				# The `compress` transfer encoding compresses the message body using the compress algorithm.
				COMPRESS = "compress"
				
				# The `identity` transfer encoding indicates no transformation has been applied.
				IDENTITY = "identity"
				
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value containing comma-separated encodings.
				# @returns [TransferEncoding] a new instance with normalized (lowercase) encodings.
				def self.parse(value)
					self.new(value.downcase.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [TransferEncoding] a parsed header object with normalized values.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:downcase))
					else
						self.parse(value.to_s)
					end
				end
				
				# Adds one or more comma-separated values to the transfer encoding header. The values are converted to lowercase for normalization.
				#
				# @parameter value [String] a raw header value containing one or more values separated by commas.
				def << value
					super(value.downcase)
				end
				
				# @returns [Boolean] whether the `chunked` encoding is present.
				def chunked?
					self.include?(CHUNKED)
				end
				
				# @returns [Boolean] whether the `gzip` encoding is present.
				def gzip?
					self.include?(GZIP)
				end
				
				# @returns [Boolean] whether the `deflate` encoding is present.
				def deflate?
					self.include?(DEFLATE)
				end
				
				# @returns [Boolean] whether the `compress` encoding is present.
				def compress?
					self.include?(COMPRESS)
				end
				
				# @returns [Boolean] whether the `identity` encoding is present.
				def identity?
					self.include?(IDENTITY)
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# Transfer-Encoding headers control message framing and must not appear in trailers.
				# @returns [Boolean] `false`, as Transfer-Encoding headers are hop-by-hop and must precede the message body.
				def self.trailer?
					false
				end
			end
		end
	end
end

