# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

module IO::Stream
	# Represents a connection reset error in IO streams, usually occurring when the remote side closes the connection unexpectedly.
	class ConnectionResetError < Errno::ECONNRESET
	end
end
