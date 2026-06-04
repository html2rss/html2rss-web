# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "encoding"

module Protocol
	module URL
		# Represents a relative URL, which does not include a scheme or authority.
		module Path
			# Split the given path into its components.
			# 
			# - `split("")` => `[]`
			# - `split("/")` => `["", ""]`
			# - `split("/a/b/c")` => `["", "a", "b", "c"]`
			# - `split("a/b/c/")` => `["a", "b", "c", ""]`
			#
			# @parameter path [String] The path to split.
			# @returns [Array(String)] The path components.
			#
			# @example Split an absolute path.
			# 	Path.split("/documents/report.pdf")
			# 	# => ["", "documents", "report.pdf"]
			#
			# @example Split a relative path.
			# 	Path.split("images/logo.png")
			# 	# => ["images", "logo.png"]
			def self.split(path)
				return path.split("/", -1)
			end
			
			# Join the given path components into a single path.
			#
			# @parameter components [Array(String)] The path components to join.
			# @returns [String] The joined path.
			#
			# @example Join absolute path components.
			# 	Path.join(["", "documents", "report.pdf"])
			# 	# => "/documents/report.pdf"
			#
			# @example Join relative path components.
			# 	Path.join(["images", "logo.png"])
			# 	# => "images/logo.png"
			def self.join(components)
				return components.join("/")
			end
			
			# Simplify the given path components by resolving "." and "..".
			#
			# @parameter components [Array(String)] The path components to simplify.
			# @returns [Array(String)] The simplified path components.
			#
			# @example Resolve parent directory references.
			# 	Path.simplify(["documents", "reports", "..", "invoices", "2024.pdf"])
			# 	# => ["documents", "invoices", "2024.pdf"]
			#
			# @example Remove current directory references.
			# 	Path.simplify(["documents", ".", "report.pdf"])
			# 	# => ["documents", "report.pdf"]
			def self.simplify(components)
				output = []
				
				components.each_with_index do |component, index|
					if index == 0 && component == ""
						# Preserve leading slash:
						output << ""
					elsif component == "."
						# Handle current directory - trailing . means directory, preserve trailing slash:
						output << "" if index == components.size - 1
					elsif component == "" && index != components.size - 1
						# Ignore empty segments (multiple slashes) except at end - no-op.
					elsif component == ".." && output.last && output.last != ".."
						# Handle parent directory: go up one level if not at root:
						output.pop if output.last != ""
						# Trailing .. means directory, preserve trailing slash:
						output << "" if index == components.size - 1
					else
						# Regular path component:
						output << component
					end
				end
				
				return output
			end
			
			# @parameter pop [Boolean] whether to remove the last path component of the base path, to conform to URI merging behaviour, as defined by RFC2396.
			#
			# @example Expand a relative path against a base path.
			# 	Path.expand("/documents/reports/", "invoices/2024.pdf")
			# 	# => "/documents/reports/invoices/2024.pdf"
			#
			# @example Navigate to parent directory.
			# 	Path.expand("/documents/reports/2024/", "../summary.pdf")
			# 	# => "/documents/reports/summary.pdf"
			def self.expand(base, relative, pop = true)
				# Empty relative path means no change:
				return base if relative.nil? || relative.empty?
				
				components = split(base)
				
				# RFC2396 Section 5.2:
				# 6) a) All but the last segment of the base URI's path component is
				# copied to the buffer.  In other words, any characters after the
				# last (right-most) slash character, if any, are excluded.
				if pop and components.last != ".."
					components.pop
				elsif components.last == ""
					components.pop
				end
				
				relative = relative.split("/", -1)
				if relative.first == ""
					components = relative
				else
					components.concat(relative)
				end
				
				return join(simplify(components))
			end
			
			# Calculate the relative path from one absolute path to another.
			#
			# This is useful for generating relative URLs from one location to another,
			# such as creating page-specific import maps or relative links.
			#
			# @parameter target [String] The destination path (where you want to go).
			# @parameter from [String] The source path (where you are starting from).
			# @returns [String] The relative path from `from` to `target`.
			#
			# @example Calculate relative path between pages.
			# 	Path.relative("/_components/app.js", "/foo/bar/")
			# 	# => "../../_components/app.js"
			#
			# @example Calculate relative path in same directory.
			# 	Path.relative("/docs/guide.html", "/docs/index.html")
			# 	# => "guide.html"
			def self.relative(target, from)
				target_components = split(target)
				from_components = split(from)
				
				# Remove the last component from 'from' to get the directory
				from_components = from_components[0...-1] if from_components.size > 0
				
				# Find the common prefix
				common_length = 0
				[target_components.size, from_components.size].min.times do |i|
					break if target_components[i] != from_components[i]
					common_length = i + 1
				end
				
				# Calculate how many levels to go up
				up_levels = from_components.size - common_length
				
				# Build the relative path components
				relative_components = [".."] * up_levels + target_components[common_length..-1]
				
				return join(relative_components)
			end
			
			# Convert a URL path to a local file system path using the platform's file separator.
			#
			# This method splits the URL path on `/` characters, unescapes each component using
			# {Encoding.unescape_path} (which preserves encoded separators), then joins the
			# components using `File.join`.
			#
			# Percent-encoded path separators (`%2F` for `/` and `%5C` for `\`) are NOT decoded,
			# preventing them from being interpreted as directory boundaries. This ensures that
			# URL path components map directly to file system path components.
			#
			# @parameter path [String] The URL path to convert (should be percent-encoded).
			# @returns [String] The local file system path.
			#
			# @example Generating local paths.
			# 	Path.to_local_path("/documents/report.pdf")  # => "/documents/report.pdf"
			# 	Path.to_local_path("/files/My%20Document.txt")  # => "/files/My Document.txt"
			#
			# @example Preserves encoded separators.
			# 	Path.to_local_path("/folder/safe%2Fname/file.txt")
			# 	# => "/folder/safe%2Fname/file.txt"
			# 	# %2F is NOT decoded to prevent creating additional path components
			def self.to_local_path(path)
				components = split(path)
				
				# Unescape each component, preserving encoded path separators
				components.map! do |component|
					Encoding.unescape_path(component)
				end
				
				return File.join(*components)
			end
		end
	end
end
