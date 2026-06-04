# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "split"
require_relative "../quoted_string"
require_relative "../error"

module Protocol
	module HTTP
		module Header
			# The `digest` header provides a digest of the message body for integrity verification.
			#
			# This header allows servers to send cryptographic hashes of the response body, enabling clients to verify data integrity. Multiple digest algorithms can be specified, and the header is particularly useful as a trailer since the digest can only be computed after the entire message body is available.
			#
			# ## Examples
			#
			# ```ruby
			# digest = Digest.new("sha-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=")
			# digest << "md5=9bb58f26192e4ba00f01e2e7b136bbd8"
			# puts digest.to_s
			# # => "sha-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=, md5=9bb58f26192e4ba00f01e2e7b136bbd8"
			# ```
			class Digest < Split
				ParseError = Class.new(Error)
				
				# https://tools.ietf.org/html/rfc3230#section-4.3.2
				ENTRY = /\A(?<algorithm>[a-zA-Z0-9][a-zA-Z0-9\-]*)\s*=\s*(?<value>.*)\z/
				
				# A single digest entry in the Digest header.
				Entry = Struct.new(:algorithm, :value) do
					# Create a new digest entry.
					#
					# @parameter algorithm [String] the digest algorithm (e.g., "sha-256", "md5").
					# @parameter value [String] the base64-encoded or hex-encoded digest value.
					def initialize(algorithm, value)
						super(algorithm.downcase, value)
					end
					
					# Convert the entry to its string representation.
					#
					# @returns [String] the formatted digest string.
					def to_s
						"#{algorithm}=#{value}"
					end
				end
				
				# Parse the `digest` header value into a list of digest entries.
				#
				# @returns [Array(Entry)] the list of digest entries with their algorithms and values.
				def entries
					self.map do |value|
						if match = value.match(ENTRY)
							Entry.new(match[:algorithm], match[:value])
						else
							raise ParseError.new("Could not parse digest value: #{value.inspect}")
						end
					end
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# @returns [Boolean] `true`, as digest headers contain integrity hashes that can only be calculated after the entire message body is available.
				def self.trailer?
					true
				end
			end
		end
	end
end
