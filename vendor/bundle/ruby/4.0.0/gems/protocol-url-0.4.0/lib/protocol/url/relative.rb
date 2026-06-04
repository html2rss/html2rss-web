# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"
require_relative "path"

module Protocol
	module URL
		# Represents a relative URL, which does not include a scheme or authority.
		class Relative
			include Comparable
			
			def initialize(path, query = nil, fragment = nil)
				@path = path.to_s
				@query = query
				@fragment = fragment
			end
			
			attr :path
			attr :query
			attr :fragment
			
			def to_local_path
				Path.to_local_path(@path)
			end
			
			# @returns [Boolean] If there is a query string.
			def query?
				@query and !@query.empty?
			end
			
			# @returns [Boolean] If there is a fragment.
			def fragment?
				@fragment and !@fragment.empty?
			end
			
			# Combine this relative URL with another URL or path.
			#
			# @parameter other [String, Absolute, Relative] The URL or path to combine.
			# @returns [Absolute, Relative] The combined URL.
			#
			# @example Combine two relative paths.
			# 	base = Relative.new("/documents/reports/")
			# 	other = Relative.new("invoices/2024.pdf")
			# 	result = base + other
			# 	result.path  # => "/documents/reports/invoices/2024.pdf"
			#
			# @example Navigate to parent directory.
			# 	base = Relative.new("/documents/reports/archive/")
			# 	other = Relative.new("../../summary.pdf")
			# 	result = base + other
			# 	result.path  # => "/documents/summary.pdf"
			def +(other)
				case other
				when Absolute
					# Relative + Absolute: the absolute URL takes precedence
					# You can't apply relative navigation to an absolute URL
					other
				when Relative
					# Relative + Relative: merge paths directly
					self.class.new(
						Path.expand(self.path, other.path, true),
						other.query,
						other.fragment
					)
				when String
					# Relative + String: parse and combine
					self + URL[other]
				else
					raise ArgumentError, "Cannot combine Relative URL with #{other.class}"
				end
			end
			
			# Create a new Relative URL with modified components.
			#
			# @parameter path [String, nil] The path to merge with the current path.
			# @parameter query [String, nil] The query string to use.
			# @parameter fragment [String, nil] The fragment to use.
			# @parameter pop [Boolean] Whether to pop the last path component before merging.
			# @returns [Relative] A new Relative URL with the modified components.
			#
			# @example Update the query string.
			# 	url = Relative.new("/search", "query=ruby")
			# 	updated = url.with(query: "query=python")
			# 	updated.to_s  # => "/search?query=python"
			#
			# @example Append to the path.
			# 	url = Relative.new("/documents/")
			# 	updated = url.with(path: "report.pdf", pop: false)
			# 	updated.to_s  # => "/documents/report.pdf"
			def with(path: nil, query: @query, fragment: @fragment, pop: true)
				self.class.new(Path.expand(@path, path, pop), query, fragment)
			end
			
			# Normalize the path by resolving "." and ".." segments and removing duplicate slashes.
			#
			# This modifies the URL in-place by simplifying the path component:
			# - Removes "." segments (current directory)
			# - Resolves ".." segments (parent directory)
			# - Collapses multiple consecutive slashes to single slashes (except at start)
			#
			# @returns [self] The normalized URL.
			#
			# @example Basic normalization
			#   url = Relative.new("/foo//bar/./baz/../qux")
			#   url.normalize!
			#   url.path  # => "/foo/bar/qux"
			def normalize!
				components = Path.split(@path)
				normalized = Path.simplify(components)
				@path = Path.join(normalized)
				
				return self
			end
			
			# Append the relative URL to the given buffer.
			# The path, query, and fragment are expected to already be properly encoded.
			def append(buffer = String.new)
				buffer << @path
				
				if @query and !@query.empty?
					buffer << "?" << @query
				end
				
				if @fragment and !@fragment.empty?
					buffer << "#" << @fragment
				end
				
				return buffer
			end
			
			def to_ary
				[@path, @query, @fragment]
			end
			
			def hash
				to_ary.hash
			end
			
			def equal?(other)
				to_ary == other.to_ary
			end
			
			def <=>(other)
				to_ary <=> other.to_ary
			end
			
			def ==(other)
				to_ary == other.to_ary
			end
			
			def ===(other)
				to_s === other
			end
			
			def to_s
				append
			end
			
			def as_json(...)
				to_s
			end
			
			def to_json(...)
				as_json.to_json(...)
			end
			
			def inspect
				"#<#{self.class} #{to_s}>"
			end
		end
	end
end
