# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require_relative "endpoint/version"
require_relative "endpoint/generic"
require_relative "endpoint/shared_endpoint"

# Represents a collection of endpoint classes for network I/O operations.
module IO::Endpoint
	# Get the current file descriptor limit for the process.
	# @returns [Integer] The soft limit for the number of open file descriptors.
	def self.file_descriptor_limit
		Process.getrlimit(Process::RLIMIT_NOFILE).first
	end
end
