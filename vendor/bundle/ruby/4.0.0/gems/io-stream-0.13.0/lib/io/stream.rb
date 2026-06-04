# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require_relative "stream/version"
require_relative "stream/buffered"
require_relative "stream/duplex"

# @namespace
class IO
	# Convert any IO-like object into a buffered stream.
	# @parameter io [IO] The IO object to wrap.
	# @returns [IO::Stream::Buffered] A buffered stream wrapper.
	def self.Stream(io)
		if io.is_a?(Stream::Buffered)
			io
		else
			Stream::Buffered.wrap(io)
		end
	end
end
