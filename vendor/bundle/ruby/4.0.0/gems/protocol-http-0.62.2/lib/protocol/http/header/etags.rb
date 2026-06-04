# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2023, by Thomas Morgan.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# The `etags` header represents a list of entity tags (ETags) for resources.
			#
			# The `etags` header is used for conditional requests to compare the current version of a resource with previously stored versions. It supports both strong and weak validators, as well as the wildcard character (`*`) to indicate a match for any resource.
			class ETags < Split
				# Checks if the `etags` header contains the wildcard (`*`) character.
				#
				# The wildcard character matches any resource version, regardless of its actual value.
				#
				# @returns [Boolean] whether the wildcard is present.
				def wildcard?
					self.include?("*")
				end
				
				# Checks if the specified ETag matches the `etags` header.
				#
				# This method returns `true` if the wildcard is present or if the exact ETag is found in the list. Note that this implementation is not strictly compliant with the RFC-specified format.
				#
				# @parameter etag [String] the ETag to compare against the `etags` header.
				# @returns [Boolean] whether the specified ETag matches.
				def match?(etag)
					wildcard? || self.include?(etag)
				end
				
				# Checks for a strong match with the specified ETag, useful with the `if-match` header.
				#
				# A strong match requires that the ETag in the header list matches the specified ETag and that neither is a weak validator.
				#
				# @parameter etag [String] the ETag to compare against the `etags` header.
				# @returns [Boolean] whether a strong match is found.
				def strong_match?(etag)
					wildcard? || (!weak_tag?(etag) && self.include?(etag))
				end
				
				# Checks for a weak match with the specified ETag, useful with the `if-none-match` header.
				#
				# A weak match allows for semantically equivalent content, including weak validators and their strong counterparts.
				#
				# @parameter etag [String] the ETag to compare against the `etags` header.
				# @returns [Boolean] whether a weak match is found.
				def weak_match?(etag)
					wildcard? || self.include?(etag) || self.include?(opposite_tag(etag))
				end
				
			private
				
				# Converts a weak tag to its strong counterpart or vice versa.
				#
				# @parameter etag [String] the ETag to convert.
				# @returns [String] the opposite form of the provided ETag.
				def opposite_tag(etag)
					weak_tag?(etag) ? etag[2..-1] : "W/#{etag}"
				end
				
				# Checks if the given ETag is a weak validator.
				#
				# @parameter tag [String] the ETag to check.
				# @returns [Boolean] whether the tag is weak.
				def weak_tag?(tag)
					tag&.start_with? "W/"
				end
			end
		end
	end
end
