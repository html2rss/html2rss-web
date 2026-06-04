# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "split"
require_relative "../quoted_string"
require_relative "../error"

module Protocol
	module HTTP
		module Header
			# The `te` header indicates the transfer encodings the client is willing to accept. AKA `accept-transfer-encoding`. How we ended up with `te` instead of `accept-transfer-encoding` is a mystery lost to time.
			#
			# The `te` header allows a client to indicate which transfer encodings it can handle, and in what order of preference using quality factors.
			class TE < Split
				ParseError = Class.new(Error)
				
				# Transfer encoding token pattern
				TOKEN = /[!#$%&'*+\-.0-9A-Z^_`a-z|~]+/
				
				# Quality value pattern (0.0 to 1.0)
				QVALUE = /0(\.[0-9]{0,3})?|1(\.[0]{0,3})?/
				
				# Pattern for parsing transfer encoding with optional quality factor
				TRANSFER_CODING = /\A(?<name>#{TOKEN})(\s*;\s*q=(?<q>#{QVALUE}))?\z/
				
				# The `chunked` transfer encoding
				CHUNKED = "chunked"
				
				# The `gzip` transfer encoding
				GZIP = "gzip"
				
				# The `deflate` transfer encoding  
				DEFLATE = "deflate"
				
				# The `compress` transfer encoding
				COMPRESS = "compress"
				
				# The `identity` transfer encoding
				IDENTITY = "identity"
				
				# The `trailers` pseudo-encoding indicates willingness to accept trailer fields
				TRAILERS = "trailers"
				
				# A single transfer coding entry with optional quality factor
				TransferCoding = Struct.new(:name, :q) do
					def quality_factor
						(q || 1.0).to_f
					end
					
					def <=> other
						other.quality_factor <=> self.quality_factor
					end
					
					def to_s
						if q && q != 1.0
							"#{name};q=#{q}"
						else
							name.to_s
						end
					end
				end
				
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value containing comma-separated encodings.
				# @returns [TE] a new instance with normalized (lowercase) encodings.
				def self.parse(value)
					self.new(value.downcase.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [TE] a parsed header object with normalized values.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:downcase))
					else
						self.parse(value.to_s)
					end
				end
				
				# Adds one or more comma-separated values to the TE header. The values are converted to lowercase for normalization.
				#
				# @parameter value [String] a raw header value containing one or more values separated by commas.
				def << value
					super(value.downcase)
				end
				
				# Parse the `te` header value into a list of transfer codings with quality factors.
				#
				# @returns [Array(TransferCoding)] the list of transfer codings and their associated quality factors.
				def transfer_codings
					self.map do |value|
						if match = value.match(TRANSFER_CODING)
							TransferCoding.new(match[:name], match[:q])
						else
							raise ParseError.new("Could not parse transfer coding: #{value.inspect}")
						end
					end
				end
				
				# @returns [Boolean] whether the `chunked` encoding is accepted.
				def chunked?
					self.any?{|value| value.start_with?(CHUNKED)}
				end
				
				# @returns [Boolean] whether the `gzip` encoding is accepted.
				def gzip?
					self.any?{|value| value.start_with?(GZIP)}
				end
				
				# @returns [Boolean] whether the `deflate` encoding is accepted.
				def deflate?
					self.any?{|value| value.start_with?(DEFLATE)}
				end
				
				# @returns [Boolean] whether the `compress` encoding is accepted.
				def compress?
					self.any?{|value| value.start_with?(COMPRESS)}
				end
				
				# @returns [Boolean] whether the `identity` encoding is accepted.
				def identity?
					self.any?{|value| value.start_with?(IDENTITY)}
				end
				
				# @returns [Boolean] whether trailers are accepted.
				def trailers?
					self.any?{|value| value.start_with?(TRAILERS)}
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# TE headers negotiate transfer encodings and must not appear in trailers.
				# @returns [Boolean] `false`, as TE headers are hop-by-hop and control message framing.
				def self.trailer?
					false
				end
			end
		end
	end
end

