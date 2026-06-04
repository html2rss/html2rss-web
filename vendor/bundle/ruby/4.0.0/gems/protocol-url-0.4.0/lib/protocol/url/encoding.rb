# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Protocol
	module URL
		# Helpers for encoding and decoding URL components.
		module Encoding
			# Escapes a string using percent encoding, e.g. `a b` -> `a%20b`.
			#
			# @parameter string [String] The string to escape.
			# @returns [String] The escaped string.
			#
			# @example Escape spaces and special characters.
			# 	Encoding.escape("hello world!")
			# 	# => "hello%20world%21"
			#
			# @example Escape unicode characters.
			# 	Encoding.escape("café")
			# 	# => "caf%C3%A9"
			def self.escape(string, encoding = string.encoding)
				string.b.gsub(/([^a-zA-Z0-9_.\-]+)/) do |m|
					"%" + m.unpack("H2" * m.bytesize).join("%").upcase
				end.force_encoding(encoding)
			end
			
			# Unescapes a percent encoded string, e.g. `a%20b` -> `a b`.
			#
			# @parameter string [String] The string to unescape.
			# @returns [String] The unescaped string.
			#
			# @example Unescape spaces and special characters.
			# 	Encoding.unescape("hello%20world%21")
			# 	# => "hello world!"
			#
			# @example Unescape unicode characters.
			# 	Encoding.unescape("caf%C3%A9")
			# 	# => "café"
			def self.unescape(string, encoding = string.encoding)
				string.b.gsub(/%(\h\h)/) do |hex|
					Integer($1, 16).chr
				end.force_encoding(encoding)
			end
			
			# Unescapes a percent encoded path component, preserving encoded path separators.
			#
			# This method unescapes percent-encoded characters except for path separators
			# (forward slash `/` and backslash `\`). This prevents encoded separators like
			# `%2F` or `%5C` from being decoded into actual path separators, which could
			# allow bypassing path component boundaries.
			#
			# @parameter string [String] The path component to unescape.
			# @returns [String] The unescaped string with separators still encoded.
			#
			# @example
			#   Encoding.unescape_path("hello%20world")     # => "hello world"
			#   Encoding.unescape_path("safe%2Fname")       # => "safe%2Fname" (%2F not decoded)
			#   Encoding.unescape_path("name%5Cfile")       # => "name%5Cfile" (%5C not decoded)
			def self.unescape_path(string, encoding = string.encoding)
				string.b.gsub(/%(\h\h)/) do |hex|
					byte = Integer($1, 16)
					char = byte.chr
					
					# Don't decode forward slash (0x2F) or backslash (0x5C)
					if byte == 0x2F || byte == 0x5C
						hex  # Keep as %2F or %5C
					else
						char
					end
				end.force_encoding(encoding)
			end
			
			# Matches characters that are not allowed in a URI path segment. According to RFC 3986 Section 3.3 (https://tools.ietf.org/html/rfc3986#section-3.3), a valid path segment consists of "pchar" characters. This pattern identifies characters that must be percent-encoded when included in a URI path segment.
			NON_PATH_CHARACTER_PATTERN = /([^a-zA-Z0-9_\-\.~!$&'()*+,;=:@\/]+)/.freeze
			
			# Matches characters that are not allowed in a URI fragment. According to RFC 3986 Section 3.5, a valid fragment consists of pchar / "/" / "?" characters.
			NON_FRAGMENT_CHARACTER_PATTERN = /([^a-zA-Z0-9_\-\.~!$&'()*+,;=:@\/\?]+)/.freeze
			
			# Escapes non-path characters using percent encoding. In other words, this method escapes characters that are not allowed in a URI path segment. According to RFC 3986 Section 3.3 (https://tools.ietf.org/html/rfc3986#section-3.3), a valid path segment consists of "pchar" characters. This method percent-encodes characters that are not "pchar" characters.
			#
			# @parameter path [String] The path to escape.
			# @returns [String] The escaped path.
			#
			# @example Escape spaces while preserving path separators.
			# 	Encoding.escape_path("/documents/my reports/summary.pdf")
			# 	# => "/documents/my%20reports/summary.pdf"
			def self.escape_path(path)
				encoding = path.encoding
				path.b.gsub(NON_PATH_CHARACTER_PATTERN) do |m|
					"%" + m.unpack("H2" * m.bytesize).join("%").upcase
				end.force_encoding(encoding)
			end
			
			# Escapes non-fragment characters using percent encoding. According to RFC 3986 Section 3.5, fragments can contain pchar / "/" / "?" characters.
			#
			# @parameter fragment [String] The fragment to escape.
			# @returns [String] The escaped fragment.
			def self.escape_fragment(fragment)
				encoding = fragment.encoding
				fragment.b.gsub(NON_FRAGMENT_CHARACTER_PATTERN) do |m|
					"%" + m.unpack("H2" * m.bytesize).join("%").upcase
				end.force_encoding(encoding)
			end
			
			# Encodes a hash or array into a query string. This method is used to encode query parameters in a URL. For example, `{"a" => 1, "b" => 2}` is encoded as `a=1&b=2`.
			#
			# @parameter value [Hash | Array | Nil] The value to encode.
			# @parameter prefix [String] The prefix to use for keys.
			#
			# @example Encode simple parameters.
			# 	Encoding.encode({"name" => "Alice", "age" => "30"})
			# 	# => "name=Alice&age=30"
			#
			# @example Encode nested parameters.
			# 	Encoding.encode({"user" => {"name" => "Alice", "role" => "admin"}})
			# 	# => "user[name]=Alice&user[role]=admin"
			def self.encode(value, prefix = nil)
				case value
				when Array
					return value.map {|v|
						self.encode(v, "#{prefix}[]")
					}.join("&")
				when Hash
					return value.map {|k, v|
						self.encode(v, prefix ? "#{prefix}[#{escape(k.to_s)}]" : escape(k.to_s))
					}.reject(&:empty?).join("&")
				when nil
					return prefix
				else
					raise ArgumentError, "value must be a Hash" if prefix.nil?
					
					return "#{prefix}=#{escape(value.to_s)}"
				end
			end
			
			# Scan a string for URL-encoded key/value pairs.
			# @yields {|key, value| ...}
			# 	@parameter key [String] The unescaped key.
			# 	@parameter value [String] The unescaped key.
			def self.scan(string)
				string.split("&") do |assignment|
					next if assignment.empty?
					
					key, value = assignment.split("=", 2)
					
					yield unescape(key), value.nil? ? value : unescape(value)
				end
			end
			
			# Split a key into parts, e.g. `a[b][c]` -> `["a", "b", "c"]`.
			#
			# @parameter name [String] The key to split.
			# @returns [Array(String)] The parts of the key.
			def self.split(name)
				name.scan(/([^\[]+)|(?:\[(.*?)\])/)&.tap do |parts|
					parts.flatten!
					parts.compact!
				end
			end
			
			# Assign a value to a nested hash.
			#
			# This method handles building nested data structures from query string parameters, including arrays of objects. When processing array elements (empty key like `[]`), it intelligently decides whether to add to the last array element or create a new one.
			#
			# @parameter keys [Array(String)] The parts of the key.
			# @parameter value [Object] The value to assign.
			# @parameter parent [Hash] The parent hash.
			#
			# @example Building an array of objects.
			# 	# Query: items[][name]=a&items[][value]=1&items[][name]=b&items[][value]=2
			# 	# When "name" appears again, it creates a new array element
			# 	# Result: {"items" => [{"name" => "a", "value" => "1"}, {"name" => "b", "value" => "2"}]}
			def self.assign(keys, value, parent)
				top, *middle = keys
				
				middle.each_with_index do |key, index|
					if key.nil? or key.empty?
						# Array element (e.g., items[]):
						parent = (parent[top] ||= Array.new)
						top = parent.size
						
						# Check if we should reuse the last array element or create a new one. If there's a nested key coming next, and the last array element already has that key, then we need a new array element. Otherwise, add to the existing one.
						if nested = middle[index+1] and last = parent.last
							# If the last element doesn't include the nested key, reuse it (decrement index).
							# If it does include the key, keep current index (creates new element).
							top -= 1 unless last.include?(nested)
						end
					else
						# Hash key (e.g., user[name]):
						parent = (parent[top] ||= Hash.new)
						top = key
					end
				end
				
				parent[top] = value
			end
			
			# Decode a URL-encoded query string into a hash.
			#
			# @parameter string [String] The query string to decode.
			# @parameter maximum [Integer] The maximum number of keys in a path.
			# @parameter symbolize_keys [Boolean] Whether to symbolize keys.
			# @returns [Hash] The decoded query string.
			#
			# @example Decode simple parameters.
			# 	Encoding.decode("name=Alice&age=30")
			# 	# => {"name" => "Alice", "age" => "30"}
			#
			# @example Decode nested parameters.
			# 	Encoding.decode("user[name]=Alice&user[role]=admin")
			# 	# => {"user" => {"name" => "Alice", "role" => "admin"}}
			def self.decode(string, maximum = 8, symbolize_keys: false)
				parameters = {}
				
				self.scan(string) do |name, value|
					keys = self.split(name)
					
					if keys.empty?
						raise ArgumentError, "Invalid key path: #{name.inspect}!"
					end
					
					if keys.size > maximum
						raise ArgumentError, "Key length exceeded limit!"
					end
					
					if symbolize_keys
						keys.collect!{|key| key.empty? ? nil : key.to_sym}
					end
					
					self.assign(keys, value, parameters)
				end
				
				return parameters
			end
		end
	end
end
