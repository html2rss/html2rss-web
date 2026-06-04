# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2024, by Thomas Morgan.

require_relative "split"

module Protocol
	module HTTP
		module Header
			# Represents the `connection` HTTP header, which controls options for the current connection.
			#
			# The `connection` header is used to specify control options such as whether the connection should be kept alive, closed, or upgraded to a different protocol.
			class Connection < Split
				# The `keep-alive` directive indicates that the connection should remain open for future requests or responses, avoiding the overhead of opening a new connection.
				KEEP_ALIVE = "keep-alive"
				
				# The `close` directive indicates that the connection should be closed after the current request and response are complete.
				CLOSE = "close"
				
				# The `upgrade` directive indicates that the connection should be upgraded to a different protocol, as specified in the `Upgrade` header.
				UPGRADE = "upgrade"
				
				# Parses a raw header value.
				#
				# @parameter value [String] a raw header value containing comma-separated directives.
				# @returns [Connection] a new instance with normalized (lowercase) directives.
				def self.parse(value)
					self.new(value.downcase.split(COMMA))
				end
				
				# Coerces a value into a parsed header object.
				#
				# @parameter value [String | Array] the value to coerce.
				# @returns [Connection] a parsed header object with normalized values.
				def self.coerce(value)
					case value
					when Array
						self.new(value.map(&:downcase))
					else
						self.parse(value.to_s)
					end
				end
				
				# Adds a directive to the `connection` header. The value will be normalized to lowercase before being added.
				#
				# @parameter value [String] a raw header value containing directives to add.
				def << value
					super(value.downcase)
				end
				
				# @returns [Boolean] whether the `keep-alive` directive is present and the connection is not marked for closure with the `close` directive.
				def keep_alive?
					self.include?(KEEP_ALIVE) && !close?
				end
				
				# @returns [Boolean] whether the `close` directive is present, indicating that the connection should be closed after the current request and response.
				def close?
					self.include?(CLOSE)
				end
				
				# @returns [Boolean] whether the `upgrade` directive is present, indicating that the connection should be upgraded to a different protocol.
				def upgrade?
					self.include?(UPGRADE)
				end
				
				# Whether this header is acceptable in HTTP trailers.
				# Connection headers control the current connection and must not appear in trailers.
				# @returns [Boolean] `false`, as connection headers are hop-by-hop and forbidden in trailers.
				def self.trailer?
					false
				end
			end
		end
	end
end

