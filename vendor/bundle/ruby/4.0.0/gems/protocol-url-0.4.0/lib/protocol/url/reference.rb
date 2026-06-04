# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "pattern"
require_relative "encoding"
require_relative "relative"

module Protocol
	module URL
		# Represents a "Hypertext Reference", which may include a path, query string, fragment, and user parameters.
		#
		# This class is designed to be easy to manipulate and combine URL references, following the rules specified in RFC2396, while supporting standard URL encoded parameters.
		#
		# Use {parse} for external/untrusted data, and {new} for constructing references from known good values.
		class Reference < Relative
			include Comparable
			
			def self.[](value, parameters = nil)
				case value
				when String
					if match = value.match(PATTERN)
						path = match[:path]
						query = match[:query]
						fragment = match[:fragment]
						
						# Unescape path and fragment for user-friendly internal storage
						# Query strings are kept as-is since they contain = and & syntax
						path = Encoding.unescape(path) if path && !path.empty?
						fragment = Encoding.unescape(fragment) if fragment
						
						self.new(path, query, fragment, parameters)
					else
						raise ArgumentError, "Invalid URL (contains whitespace or control characters): #{value.inspect}"
					end
				when Relative
					# Relative stores encoded values, so we need to unescape them for Reference
					path = value.path
					fragment = value.fragment
					
					path = Encoding.unescape(path) if path && !path.empty?
					fragment = Encoding.unescape(fragment) if fragment
					
					self.new(path, value.query, fragment, parameters)
				when nil
					nil
				else
					raise ArgumentError, "Cannot coerce #{value.inspect} to Reference!"
				end
			end			# Generate a reference from a path and user parameters. The path may contain a `#fragment` or `?query=parameters`.
			#
			# @example Parse a path with query and fragment.
			# 	reference = Reference.parse("/search?query=ruby#results")
			# 	reference.path      # => "/search"
			# 	reference.query     # => "query=ruby"
			# 	reference.fragment  # => "results"
			def self.parse(value = "/", parameters = nil)
				self.[](value, parameters)
			end
			
			# Initialize the reference with raw, unescaped values.
			#
			# @parameter path [String] The unescaped path.
			# @parameter query [String | Nil] An already-formatted query string.
			# @parameter fragment [String | Nil] The unescaped fragment.
			# @parameter parameters [Hash | Nil] User supplied parameters that will be safely encoded.
			#
			# @example Create a reference with parameters.
			# 	reference = Reference.new("/search", nil, nil, {"query" => "ruby", "limit" => "10"})
			# 	reference.to_s  # => "/search?query=ruby&limit=10"
			def initialize(path = "/", query = nil, fragment = nil, parameters = nil)
				super(path, query, fragment)
				@parameters = parameters
			end
			
			# @attribute [Hash] User supplied parameters that will be appended to the query part.
			attr :parameters
			
			# Freeze the reference.
			#
			#	@returns [Reference] The frozen reference.
			def freeze
				return self if frozen?
				
				@parameters.freeze
				
				super
			end
			
			# Implicit conversion to an array.
			#
			# @returns [Array] The reference as an array, `[path, query, fragment, parameters]`.
			def to_ary
				[@path, @query, @fragment, @parameters]
			end
			
			# @returns [Boolean] Whether the reference has parameters.
			def parameters?
				@parameters and !@parameters.empty?
			end
			
			# Parse the query string into parameters and merge with existing parameters.
			#
			# Afterwards, the `query` attribute will be cleared.
			#
			# @returns [Hash] The merged parameters.
			def parse_query!(encoding = Encoding)
				if @query and !@query.empty?
					parsed = encoding.decode(@query)
					
					if @parameters
						@parameters = @parameters.merge(parsed)
					else
						@parameters = parsed
					end
					
					@query = nil
				end
				
				return @parameters
			end
			
			# @returns [Boolean] Whether the reference has a query string.
			def query?
				@query and !@query.empty?
			end
			
			# @returns [Boolean] Whether the reference has a fragment.
			def fragment?
				@fragment and !@fragment.empty?
			end
			
			# Append the reference to the given buffer.
			# Encodes the path and fragment which are stored unescaped internally.
			# Query strings are passed through as-is (they contain = and & which are valid syntax).
			def append(buffer = String.new)
				buffer << Encoding.escape_path(@path)
				
				if @query and !@query.empty?
					buffer << "?" << @query
					buffer << "&" << Encoding.encode(@parameters) if parameters?
				elsif parameters?
					buffer << "?" << Encoding.encode(@parameters)
				end
				
				if @fragment and !@fragment.empty?
					buffer << "#" << Encoding.escape_fragment(@fragment)
				end
				
				return buffer
			end
			
			# Merges two references as specified by RFC2396, similar to `URI.join`.
			def + other
				other = self.class[other]
				
				self.class.new(
					Path.expand(self.path, other.path, true),
					other.query,
					other.fragment,
					other.parameters,
				)
			end
			
			# Just the base path, without any query string, parameters or fragment.
			def base
				self.class.new(@path, nil, nil, nil)
			end
			
			# Update the reference with the given path, query, fragment, and parameters.
			#
			# @parameter path [String] Append the string to this reference similar to `File.join`.
			# @parameter query [String | Nil] Replace the query string. Defaults to keeping the existing query if not specified.
			# @parameter fragment [String | Nil] Replace the fragment. Defaults to keeping the existing fragment if not specified.
			# @parameter parameters [Hash | false] Parameters to merge or replace. Pass `false` (default) to keep existing parameters.
			# @parameter pop [Boolean] If the path contains a trailing filename, pop the last component of the path before appending the new path.
			# @parameter merge [Boolean] Controls how parameters are handled. When `true` (default), new parameters are merged with existing ones and query is kept. When `false` and new parameters are provided, parameters replace existing ones and query is cleared. Explicitly passing `query:` always overrides this behavior.
			#
			# @example Merge parameters.
			# 	reference = Reference.new("/search", nil, nil, {"query" => "ruby"})
			# 	updated = reference.with(parameters: {"limit" => "10"})
			# 	updated.to_s  # => "/search?query=ruby&limit=10"
			#
			# @example Replace parameters.
			# 	reference = Reference.new("/search", nil, nil, {"query" => "ruby"})
			# 	updated = reference.with(parameters: {"query" => "python"}, merge: false)
			# 	updated.to_s  # => "/search?query=python"
			def with(path: nil, query: false, fragment: @fragment, parameters: false, pop: false, merge: true)
				if merge
					# If merging, we keep existing query unless explicitly overridden:
					if query == false
						query = @query
					end
					
					# Merge mode: combine new parameters with existing, keep query:
					# parameters = (@parameters || {}).merge(parameters || {})
					if @parameters
						if parameters
							parameters = @parameters.merge(parameters)
						else
							parameters = @parameters
						end
					elsif !parameters
						parameters = @parameters
					end
				else
					# Replace mode: use new parameters if provided, clear query when replacing:
					if parameters == false
						# No new parameters provided, keep existing:
						parameters = @parameters
						
						# Also keep query if not explicitly specified:
						if query == false
							query = @query
						end
					else
						# New parameters provided, clear query unless explicitly specified:
						if query == false
							query = nil
						end
					end
				end
				
				path = Path.expand(@path, path, pop)
				
				self.class.new(path, query, fragment, parameters)
			end
		end
	end
end
