# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require_relative "error"

require_relative "header/split"
require_relative "header/multiple"

require_relative "header/cookie"
require_relative "header/connection"
require_relative "header/cache_control"
require_relative "header/etag"
require_relative "header/etags"
require_relative "header/vary"
require_relative "header/authorization"
require_relative "header/date"
require_relative "header/priority"
require_relative "header/trailer"
require_relative "header/server_timing"
require_relative "header/digest"
require_relative "header/generic"

require_relative "header/accept"
require_relative "header/accept_charset"
require_relative "header/accept_encoding"
require_relative "header/accept_language"
require_relative "header/transfer_encoding"
require_relative "header/te"

module Protocol
	module HTTP
		# @namespace
		module Header
		end
		
		# Headers are an array of key-value pairs. Some header keys represent multiple values.
		class Headers
			Split = Header::Split
			Multiple = Header::Multiple
			
			TRAILER = "trailer"
			
			# Construct an instance from a headers Array or Hash. No-op if already an instance of `Headers`. If the underlying array is frozen, it will be duped.
			#
			# @return [Headers] an instance of headers.
			def self.[] headers
				if headers.nil?
					return self.new
				end
				
				if headers.is_a?(self)
					if headers.frozen?
						return headers.dup
					else
						return headers
					end
				end
				
				fields = headers.to_a
				
				if fields.frozen?
					fields = fields.dup
				end
				
				return self.new(fields)
			end
			
			# Initialize the headers with the specified fields.
			#
			# @parameter fields [Array] An array of `[key, value]` pairs.
			# @parameter tail [Integer | Nil] The index of the trailer start in the @fields array.
			def initialize(fields = [], tail = nil, indexed: nil, policy: POLICY)
				@fields = fields
				
				# Marks where trailer start in the @fields array:
				@tail = tail
				
				# The cached index of headers:
				@indexed = nil
				
				@policy = policy
			end
			
			# @attribute [Hash] The policy for the headers.
			attr :policy
			
			# Set the policy for the headers.
			#
			# The policy is used to determine how headers are merged and normalized. For example, if a header is specified multiple times, the policy will determine how the values are merged.
			#
			# @parameter policy [Hash] The policy for the headers.
			def policy=(policy)
				@policy = policy
				@indexed = nil
			end
			
			# Initialize a copy of the headers.
			#
			# @parameter other [Headers] The headers to copy.
			def initialize_dup(other)
				super
				
				@fields = @fields.dup
				@indexed = @indexed.dup
			end
			
			# Clear all headers.
			def clear
				@fields.clear
				@tail = nil
				@indexed = nil
			end
			
			# Flatten trailer into the headers, in-place.
			def flatten!
				if @tail
					self.delete(TRAILER)
					@tail = nil
				end
				
				return self
			end
			
			# Flatten trailer into the headers, returning a new instance of {Headers}.
			def flatten
				self.dup.flatten!
			end
			
			# @attribute [Array] An array of `[key, value]` pairs.
			attr :fields
			
			# @attribute [Integer | Nil] The index where trailers begin.
			attr :tail
			
			# @returns [Array] The fields of the headers.
			def to_a
				@fields
			end
			
			# @returns [Boolean] Whether there are any trailers.
			def trailer?
				@tail != nil
			end
			
			# Record the current headers, and prepare to add trailers.
			#
			# This method is typically used after headers are sent to capture any additional headers which should then be sent as trailers.
			#
			# A sender that intends to generate one or more trailer fields in a message should generate a trailer header field in the header section of that message to indicate which fields might be present in the trailers.
			#
			# @parameter names [Array] The trailer header names which will be added later.
			# @yields {|name, value| ...} the trailing headers if a block is given.
			# @returns An enumerator which is suitable for iterating over trailers.
			def trailer!(&block)
				@tail ||= @fields.size
				
				return trailer(&block)
			end
			
			# Enumerate all the headers in the header, if there are any.
			# 
			# @yields {|key, value| ...} The header key and value.
			# 	@parameter key [String] The header key.
			# 	@parameter value [String] The raw header value.
			def header(&block)
				return to_enum(:header) unless block_given?
				
				if @tail and @tail < @fields.size
					@fields.first(@tail).each(&block)
				else
					@fields.each(&block)
				end
			end
			
			# Enumerate all headers in the trailer, if there are any.
			# 
			# @yields {|key, value| ...} The header key and value.
			# 	@parameter key [String] The header key.
			# 	@parameter value [String] The raw header value.
			def trailer(&block)
				return to_enum(:trailer) unless block_given?
				
				if @tail
					@fields.drop(@tail).each(&block)
				end
			end
			
			# Freeze the headers, and ensure the indexed hash is generated.
			def freeze
				return if frozen?
				
				# Ensure @indexed is generated:
				self.to_h
				
				@fields.freeze
				@indexed.freeze
				
				super
			end
			
			# @returns [Boolean] Whether the headers are empty.
			def empty?
				@fields.empty?
			end
			
			# Enumerate all header keys and values.
			#
			# @yields {|key, value| ...}
			# 	@parameter key [String] The header key.
			# 	@parameter value [String] The raw header value.
			def each(&block)
				@fields.each(&block)
			end
			
			# @returns [Boolean] Whether the headers include the specified key.
			def include? key
				self[key] != nil
			end
			
			alias key? include?
			
			# @returns [Array] All the keys of the headers.
			def keys
				self.to_h.keys
			end
			
			# Extract the specified keys from the headers.
			#
			# @parameter keys [Array] The keys to extract.
			def extract(keys)
				deleted, @fields = @fields.partition do |field|
					keys.include?(field.first.downcase)
				end
				
				if @indexed
					keys.each do |key|
						@indexed.delete(key)
					end
				end
				
				return deleted
			end
			
			# Add the specified header key value pair.
			#
			# @parameter key [String] the header key.
			# @parameter value [String] the header value to assign.
			# @parameter trailer [Boolean] whether this header is being added as a trailer.
			def add(key, value, trailer: self.trailer?)
				value = value.to_s
				
				if trailer
					policy = @policy[key.downcase]
					
					if !policy or !policy.trailer?
						raise InvalidTrailerError, key
					end
				end
				
				if @indexed
					merge_into(@indexed, key.downcase, value)
				end
				
				@fields << [key, value]
			end
			
			# Set the specified header key to the specified value, replacing any existing header keys with the same name.
			#
			# @parameter key [String] the header key to replace.
			# @parameter value [String] the header value to assign.
			def set(key, value)
				self.delete(key)
				self.add(key, value)
			end
			
			# Set the specified header key to the specified value, replacing any existing values.
			#
			# The value can be a String or a coercable value.
			#
			# @parameter key [String] the header key.
			# @parameter value [String | Array] the header value to assign.
			def []=(key, value)
				key = key.downcase
				
				# Delete existing value if any:
				self.delete(key)
				
				if policy = @policy[key]
					unless value.is_a?(policy)
						value = policy.coerce(value)
					end
				else
					value = value.to_s
				end
				
				# Clear the indexed cache so it will be rebuilt with parsed values when accessed:
				if @indexed
					@indexed[key] = value
				end
				
				@fields << [key, value.to_s]
			end
			
			# Get the value of the specified header key.
			#
			# @parameter key [String] The header key.
			# @returns [String | Array | Object] The header value.
			def [] key
				self.to_h[key]
			end
			
			# Merge the headers into this instance.
			def merge!(headers)
				headers.each do |key, value|
					self.add(key, value)
				end
				
				return self
			end
			
			# Merge the headers into a new instance of {Headers}.
			def merge(headers)
				self.dup.merge!(headers)
			end
			
			# The policy for various headers, including how they are merged and normalized.
			#
			# A policy may be `false` to indicate that the header may only be specified once and is a simple string.
			#
			# Otherwise, the policy is a class which implements the header normalization logic, including `parse` and `coerce` class methods.
			POLICY = {
				# Headers which may only be specified once:
				"content-disposition" => false,
				"content-length" => false,
				"content-type" => false,
				"expect" => false,
				"from" => false,
				"host" => false,
				"location" => false,
				"max-forwards" => false,
				"range" => false,
				"referer" => false,
				"retry-after" => false,
				"server" => false,
				"transfer-encoding" => Header::TransferEncoding,
				"user-agent" => false,
				"trailer" => Header::Trailer,
				
				# Connection handling:
				"connection" => Header::Connection,
				"upgrade" => Header::Split,
				
				# Cache handling:
				"cache-control" => Header::CacheControl,
				"te" => Header::TE,
				"vary" => Header::Vary,
				"priority" => Header::Priority,
				
				# Headers specifically for proxies:
				"via" => Split,
				"x-forwarded-for" => Split,
				
				# Authorization headers:
				"authorization" => Header::Authorization,
				"proxy-authorization" => Header::Authorization,
				
				# Cache validations:
				"etag" => Header::ETag,
				"if-match" => Header::ETags,
				"if-none-match" => Header::ETags,
				"if-range" => false,
				
				# Headers which may be specified multiple times, but which can't be concatenated:
				"www-authenticate" => Multiple,
				"proxy-authenticate" => Multiple,
				
				# Custom headers:
				"set-cookie" => Header::SetCookie,
				"cookie" => Header::Cookie,
				
				# Date headers:
				# These headers include a comma as part of the formatting so they can't be concatenated.
				"date" => Header::Date,
				"expires" => Header::Date,
				"last-modified" => Header::Date,
				"if-modified-since" => Header::Date,
				"if-unmodified-since" => Header::Date,
				
				# Accept headers:
				"accept" => Header::Accept,
				"accept-ranges" => Header::Split,
				"accept-charset" => Header::AcceptCharset,
				"accept-encoding" => Header::AcceptEncoding,
				"accept-language" => Header::AcceptLanguage,
				
				# Content negotiation headers:
				"content-encoding" => Header::Split,
				"content-range" => false,
				
				# Performance headers:
				"server-timing" => Header::ServerTiming,
				
				# Content integrity headers:
				"digest" => Header::Digest,
			}.tap{|hash| hash.default = Header::Generic}
			
			# Delete all header values for the given key, and return the merged value.
			#
			# @parameter key [String] The header key.
			# @returns [String | Array | Object] The merged header value.
			def delete(key)
				# If we've indexed the headers, we can bail out early if the key is not present:
				if @indexed && !@indexed.key?(key.downcase)
					return nil
				end
				
				deleted, @fields = @fields.partition do |field|
					field.first.downcase == key
				end
				
				if deleted.empty?
					return nil
				end
				
				if @indexed
					return @indexed.delete(key)
				elsif policy = @policy[key]
					(key, value), *tail = deleted
					merged = policy.parse(value)
					
					tail.each{|k,v| merged << v}
					
					return merged
				else
					key, value = deleted.last
					return value
				end
			end
			
			# Merge the value into the hash according to the policy for the given key.
			# 
			# @parameter hash [Hash] The hash to merge into.
			# @parameter key [String] The header key.
			# @parameter value [String] The raw header value.
			protected def merge_into(hash, key, value)
				if policy = @policy[key]
					if current_value = hash[key]
						current_value << value
					else
						hash[key] = policy.parse(value)
					end
				else
					if hash.key?(key)
						raise DuplicateHeaderError.new(key, hash[key], value)
					end
					
					hash[key] = value
				end
			end
			
			# Compute a hash table of headers, where the keys are normalized to lower case and the values are normalized according to the policy for that header.
			#
			# This will enforce policy rules, such as merging multiple headers into arrays, or raising errors for duplicate headers.
			# 
			# @returns [Hash] A hash table of `{key, value}` pairs.
			def to_h
				unless @indexed
					indexed = {}
					
					@fields.each do |key, value|
						merge_into(indexed, key.downcase, value)
					end
					
					# Deferred assignment so that exceptions in `merge_into` don't leave us in an inconsistent state:
					@indexed = indexed
				end
				
				return @indexed
			end
			
			alias as_json to_h
			
			# Inspect the headers.
			#
			# @returns [String] A string representation of the headers.
			def inspect
				"#<#{self.class} #{@fields.inspect}>"
			end
			
			# Compare this object to another object. May depend on the order of the fields.
			#
			# @returns [Boolean] Whether the other object is equal to this one.
			def == other
				case other
				when Hash
					self.to_h == other
				when Headers
					@fields == other.fields
				else
					@fields == other
				end
			end
			
			# Used for merging objects into a sequential list of headers. Normalizes header keys and values.
			class Merged
				include Enumerable
				
				# Construct a merged list of headers.
				#
				# @parameter *all [Array] An array of all headers to merge.
				def initialize(*all)
					@all = all
				end
				
				# @returns [Array] A list of all headers, in the order they were added, as `[key, value]` pairs.
				def fields
					each.to_a
				end
				
				# @returns [Headers] A new instance of {Headers} containing all the merged headers.
				def flatten
					Headers.new(fields)
				end
				
				# Clear the references to all headers.
				def clear
					@all.clear
				end
				
				# Add a new set of headers to the merged list.
				#
				# @parameter headers [Headers | Array | Hash] A list of headers to add.
				def << headers
					@all << headers
					
					return self
				end
				
				# Enumerate all headers in the merged list.
				#
				# @yields {|key, value| ...} The header key and value.
				# 	@parameter key [String] The header key (lower case).
				# 	@parameter value [String] The header value.
				def each(&block)
					return to_enum unless block_given?
					
					@all.each do |headers|
						headers.each do |key, value|
							yield key.to_s.downcase, value.to_s
						end
					end
				end
			end
		end
	end
end
