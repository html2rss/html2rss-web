# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "relative"

module Protocol
	module URL
		# Represents an absolute URL with scheme and/or authority.
		# Examples: "https://example.com/path", "//cdn.example.com/lib.js", "http://localhost/"
		class Absolute < Relative
			def initialize(scheme, authority, path = "/", query = nil, fragment = nil)
				@scheme = scheme
				@authority = authority
				
				# Initialize the parent Relative class with the path component
				super(path, query, fragment)
			end
			
			attr :scheme
			attr :authority
			
			def scheme?
				@scheme and !@scheme.empty?
			end
			
			def authority?
				@authority and !@authority.empty?
			end
			
			# Combine this absolute URL with a relative reference according to RFC 3986 Section 5.
			#
			# @parameter other [String, Relative, Reference, Absolute] The reference to resolve.
			# @returns [Absolute, String] The resolved absolute URL.
			#
			# @example Resolve a relative path.
			# 	base = Absolute.new("https", "example.com", "/documents/reports/")
			# 	relative = Relative.new("summary.pdf")
			# 	result = base + relative
			# 	result.to_s  # => "https://example.com/documents/reports/summary.pdf"
			#
			# @example Navigate to parent directory.
			# 	base = Absolute.new("https", "example.com", "/documents/reports/2024/")
			# 	relative = Relative.new("../../archive/")
			# 	result = base + relative
			# 	result.to_s  # => "https://example.com/documents/archive/"
			def +(other)
				case other
				when Absolute
					# If other is already absolute with a scheme, return it as-is:
					return other if other.scheme
					# Protocol-relative URL: inherit scheme from base:
					return Absolute.new(@scheme, other.authority, other.path, other.query, other.fragment)
				when Relative
					# Already a Relative, use directly.
				when String
					other = URL[other]
					# If parsing resulted in an Absolute URL, handle it:
					if other.is_a?(Absolute)
						return other if other.scheme
						# Protocol-relative URL: inherit scheme from base:
						return Absolute.new(@scheme, other.authority, other.path, other.query, other.fragment)
					end
				else
					raise ArgumentError, "Cannot combine Absolute URL with #{other.class}"
				end
				
				# RFC 3986 Section 5.3: Component Recomposition
				# At this point, other is a Relative URL
				
				# Check for special cases first:
				if other.path.empty?
					# Empty path - could be query-only or fragment-only reference:
					if other.query
						# Query replacement: use base path with new query:
						Absolute.new(@scheme, @authority, @path, other.query, other.fragment)
					else
						# Fragment-only: keep everything from base, just change fragment:
						Absolute.new(@scheme, @authority, @path, @query, other.fragment || @fragment)
					end
				else
					# Relative path: merge with base path:
					path = Path.expand(@path, other.path)
					Absolute.new(@scheme, @authority, path, other.query, other.fragment)
				end
			end
			
			# Append the absolute URL to the given buffer.
			def append(buffer = String.new)
				buffer << @scheme << ":" if @scheme
				buffer << "//" << @authority if @authority
				super(buffer)
			end
			
			UNSPECIFIED = Object.new
			
			# Create a new Absolute URL with modified components.
			#
			# @parameter scheme [String, nil] The scheme to use (nil to remove scheme).
			# @parameter authority [String, nil] The authority to use (nil to remove authority).
			# @parameter path [String, nil] The path to merge with the current path.
			# @parameter query [String, nil] The query string to use.
			# @parameter fragment [String, nil] The fragment to use.
			# @parameter pop [Boolean] Whether to pop the last path component before merging.
			# @returns [Absolute] A new Absolute URL with the modified components.
			#
			# @example Change the scheme.
			# 	url = Absolute.new("http", "example.com", "/page")
			# 	secure = url.with(scheme: "https")
			# 	secure.to_s  # => "https://example.com/page"
			#
			# @example Update the query string.
			# 	url = Absolute.new("https", "example.com", "/search", "query=ruby")
			# 	updated = url.with(query: "query=python")
			# 	updated.to_s  # => "https://example.com/search?query=python"
			def with(scheme: @scheme, authority: @authority, path: nil, query: @query, fragment: @fragment, pop: true)
				self.class.new(scheme, authority, Path.expand(@path, path, pop), query, fragment)
			end
			
			def to_ary
				[@scheme, @authority, @path, @query, @fragment]
			end
			
			def <=>(other)
				to_ary <=> other.to_ary
			end
			
			def to_s
				append
			end
		end
	end
end
