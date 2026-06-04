# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2024, by Maruth Goyal.
# Copyright, 2024, by Nathan Froyd.

require_relative "huffman"

module Protocol
	# Implementation of header compression for HTTP 2.0 (HPACK) format adapted
	# to efficiently represent HTTP headers in the context of HTTP 2.0.
	#
	# - http://tools.ietf.org/html/draft-ietf-httpbis-header-compression-10
	module HPACK
		# Header representation as defined by the spec.
		NO_INDEX_TYPE = {prefix: 4, pattern: 0x00}.freeze
		NEVER_INDEXED_TYPE = {prefix: 4, pattern: 0x10}.freeze
		CHANGE_TABLE_SIZE_TYPE = {prefix: 5, pattern: 0x20}.freeze
		INCREMENTAL_TYPE = {prefix: 6, pattern: 0x40}.freeze
		INDEXED_TYPE = {prefix: 7, pattern: 0x80}.freeze
		HEADER_REPRESENTATION = {
			indexed: INDEXED_TYPE,
			incremental: INCREMENTAL_TYPE,
			no_index: NO_INDEX_TYPE,
			never_indexed: NEVER_INDEXED_TYPE,
			change_table_size: CHANGE_TABLE_SIZE_TYPE
		}
		
		# To decompress header blocks, a decoder only needs to maintain a
		# dynamic table as a decoding context.
		# No other state information is needed.
		class Context
			# Static header table.
			# https://tools.ietf.org/html/rfc7541#appendix-A
			STATIC_TABLE = [
				[":authority", ""],
				[":method", "GET"],
				[":method", "POST"],
				[":path", "/"],
				[":path", "/index.html"],
				[":scheme", "http"],
				[":scheme", "https"],
				[":status", "200"],
				[":status", "204"],
				[":status", "206"],
				[":status", "304"],
				[":status", "400"],
				[":status", "404"],
				[":status", "500"],
				["accept-charset", ""],
				["accept-encoding", "gzip, deflate"],
				["accept-language", ""],
				["accept-ranges", ""],
				["accept", ""],
				["access-control-allow-origin", ""],
				["age", ""],
				["allow", ""],
				["authorization", ""],
				["cache-control", ""],
				["content-disposition", ""],
				["content-encoding", ""],
				["content-language", ""],
				["content-length", ""],
				["content-location", ""],
				["content-range", ""],
				["content-type", ""],
				["cookie", ""],
				["date", ""],
				["etag", ""],
				["expect", ""],
				["expires", ""],
				["from", ""],
				["host", ""],
				["if-match", ""],
				["if-modified-since", ""],
				["if-none-match", ""],
				["if-range", ""],
				["if-unmodified-since", ""],
				["last-modified", ""],
				["link", ""],
				["location", ""],
				["max-forwards", ""],
				["proxy-authenticate", ""],
				["proxy-authorization", ""],
				["range", ""],
				["referer", ""],
				["refresh", ""],
				["retry-after", ""],
				["server", ""],
				["set-cookie", ""],
				["strict-transport-security", ""],
				["transfer-encoding", ""],
				["user-agent", ""],
				["vary", ""],
				["via", ""],
				["www-authenticate", ""],
			].each(&:freeze).freeze

			STATIC_EXACT_LOOKUP = {}
			STATIC_NAME_LOOKUP = {}

			STATIC_TABLE.each_with_index do |(name, value), i|
				exact_header_values = (STATIC_EXACT_LOOKUP[name] ||= [])
				exact_header_values << [value, i]
				STATIC_NAME_LOOKUP[name] = i if STATIC_NAME_LOOKUP[name].nil?
			end

			STATIC_EXACT_LOOKUP.each {|k, v| v.freeze}
			STATIC_EXACT_LOOKUP.freeze
			STATIC_NAME_LOOKUP.freeze

			# Initializes compression context with appropriate client/server defaults and maximum size of the dynamic table.
			#
			# @param table [Array] Table of header key-value pairs.
			# @option huffman [Symbol] One of `:always`, `:never`, `:shorter`. Controls use of compression.
			# @option index [Symbol] One of `:all`, `:static`, `:never`. Controls use of static/dynamic tables.
			# @option table_size [Integer] The current maximum dynamic table size.
			def initialize(table = nil, huffman: :shorter, index: :all, table_size: 4096)
				@huffman = huffman
				@index = index
				
				@table_size = table_size
				
				@table = (table&.dup) || []
			end
			
			def initialize_copy(other)
				super
				
				# This is the only mutable state:
				@table = @table.dup
			end
			
			# Current table of header key-value pairs.
			attr :table
			
			attr :huffman
			attr :index
			
			attr :table_size
			
			# Finds an entry in current dynamic table by index.
			# Note that index is zero-based in this module.
			#
			# If the index is greater than the last index in the static table,
			# an entry in the dynamic table is dereferenced.
			#
			# If the index is greater than the last header index, an error is raised.
			#
			# @param index [Integer] zero-based index in the dynamic table.
			# @return [Array] +[key, value]+
			def dereference(index)
				# NOTE: index is zero-based in this module.
				value = STATIC_TABLE[index] || @table[index - STATIC_TABLE.size]
				
				if value.nil?
					raise CompressionError, "Index #{index} too large!"
				end
				
				return value
			end

			# Header Block Processing
			# - http://tools.ietf.org/html/draft-ietf-httpbis-header-compression-10#section-4.1
			#
			# @param command [Hash] {type:, name:, value:, index:}
			# @return [Array] +[name, value]+ header field that is added to the decoded header list
			def decode(command)
				emit = nil

				case command[:type]
				when :change_table_size
					self.table_size = command[:value]

				when :indexed
					# Indexed Representation
					# An _indexed representation_ entails the following actions:
					# o  The header field corresponding to the referenced entry in either
					# the static table or dynamic table is added to the decoded header
					# list.
					idx = command[:name]

					k, v = dereference(idx)
					emit = [k, v]

				when :incremental, :no_index, :never_indexed
					# A _literal representation_ that is _not added_ to the dynamic table
					# entails the following action:
					# o  The header field is added to the decoded header list.

					# A _literal representation_ that is _added_ to the dynamic table
					# entails the following actions:
					# o  The header field is added to the decoded header list.
					# o  The header field is inserted at the beginning of the dynamic table.

					if command[:name].is_a? Integer
						k, v = dereference(command[:name])

						command = command.dup
						command[:index] ||= command[:name]
						command[:value] ||= v
						command[:name] = k
					end

					emit = [command[:name], command[:value]]

					add_to_table(emit) if command[:type] == :incremental

				else
					raise CompressionError, "Invalid type: #{command[:type]}"
				end

				return emit
			end

			# Plan header compression according to +@index+
			#  :never   Do not use dynamic table or static table reference at all.
			#  :static  Use static table only.
			#  :all     Use all of them.
			#
			# @param headers [Array] +[[name, value], ...]+
			# @return [Array] array of commands
			def encode(headers)
				commands = []
				
				# Literals commands are marked with :no_index when index is not used
				no_index = [:static, :never].include?(@index)
				
				headers.each do |field, value|
					command = add_command(field, value)
					command[:type] = :no_index if no_index && command[:type] == :incremental
					commands << command
					
					decode(command)
				end
				
				return commands
			end

			# Emits command for a header.
			# Prefer static table over dynamic table.
			# Prefer exact match over name-only match.
			#
			# +@index+ controls whether to use the dynamic table,
			# static table, or both.
			#  :never   Do not use dynamic table or static table reference at all.
			#  :static  Use static table only.
			#  :all     Use all of them.
			#
			# @param name [String]
			# @param value [String]
			# @return [Hash] command
			def add_command(name, value)
				exact = nil
				name_only = nil

				if @index == :all || @index == :static
					if (values_and_indices = STATIC_EXACT_LOOKUP[name])
						values_and_indices.each do |known_value, index|
							if value == known_value
								exact = index
								break
							end
						end
						
						needs_name_lookup = exact.nil?
					else
						needs_name_lookup = true
					end

					if needs_name_lookup && (static_value = STATIC_NAME_LOOKUP[name])
						name_only = static_value
					end
				end

				if @index == :all && !exact
					@table.each_index do |i|
						entry = @table[i]
						if entry.first == name
							if entry.last == value
								exact ||= i + STATIC_TABLE.size
								break
							else
								name_only ||= i + STATIC_TABLE.size
							end
						end
					end
				end

				if exact
					{name: exact, type: :indexed}
				elsif name_only
					{name: name_only, value: value, type: :incremental}
				else
					{name: name, value: value, type: :incremental}
				end
			end

			# Alter dynamic table size.
			#  When the size is reduced, some headers might be evicted.
			def table_size= size
				@table_size = size
				size_check(nil)
			end
			
			def change_table_size(size)
				self.table_size = size
				
				# The command to resize the table:
				return {type: :change_table_size, value: size}
			end
			
			# Returns current table size in octets
			# @return [Integer]
			def compute_current_table_size
				@table.sum { |k, v| k.bytesize + v.bytesize + 32 }
			end

			private

			# Add a name-value pair to the dynamic table. Older entries might have been evicted so that the new entry fits in the dynamic table. The command and the component strings will be frozen.
			#
			# @param command [Array] +[name, value]+
			def add_to_table(command)
				return unless size_check(command)
				
				command.each(&:freeze)
				command.freeze
				
				@table.unshift(command)
				@current_table_size += entry_size(command)
			end

			def entry_size(e)
				e[0].bytesize + e[1].bytesize + 32
			end

			# To keep the dynamic table size lower than or equal to @table_size,
			# remove one or more entries at the end of the dynamic table.
			#
			# @param command [Hash]
			# @return [Boolean] whether +command+ fits in the dynamic table.
			def size_check(command)
				
				@current_table_size ||= compute_current_table_size

				cmdsize = command.nil? ? 0 : command[0].bytesize + command[1].bytesize + 32

				while @current_table_size + cmdsize > @table_size
					break if @table.empty?

					e = @table.pop
					@current_table_size -= e[0].bytesize + e[1].bytesize + 32
				end

				cmdsize <= @table_size
			end
		end
	end
end
