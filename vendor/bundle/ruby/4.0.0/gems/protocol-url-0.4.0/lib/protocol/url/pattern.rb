# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module URL
		# RFC 3986 URI pattern with named capture groups.
		# Matches: [scheme:][//authority][path][?query][#fragment]
		# Rejects strings containing whitespace or control characters (matching standard URI behavior).
		PATTERN = %r{
			\A
			(?:(?<scheme>[a-z][a-z0-9+.-]*):)?      # scheme (optional)
			(?://(?<authority>[^/?#\s]*))?          # authority (optional, without //, no whitespace)
			(?<path>[^?#\s]*)                       # path (no whitespace)
			(?:\?(?<query>[^#\s]*))?                # query (optional, no whitespace)
			(?:\#(?<fragment>[^\s]*))?              # fragment (optional, no whitespace)
			\z
		}ix
	end
end
