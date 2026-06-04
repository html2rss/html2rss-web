# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.
# Copyright, 2026, by Delton Ding.

require "digest"
require "fileutils"
require "tmpdir"

require_relative "address_endpoint"

module IO::Endpoint
	# This class doesn't exert ownership over the specified unix socket and ensures exclusive access by using `flock` where possible.
	class UNIXEndpoint < AddressEndpoint
		# Compute a stable temporary UNIX socket path for an overlong path.
		# @parameter path [String] The original (possibly overlong) path.
		# @returns [String] A short, stable path suitable for {Address.unix}.
		def self.short_path_for(path)
			# We need to ensure the path is absolute and canonical, otherwise the SHA1 hash will not be consistent:
			path = File.expand_path(path)
			
			# We then use the SHA1 hash of the path to create a short, stable path:
			File.join(Dir.tmpdir, Digest::SHA1.hexdigest(path) + ".ipc")
		end
		
		# Initialize a new UNIX domain socket endpoint.
		# @parameter path [String] The path to the UNIX socket.
		# @parameter type [Integer] The socket type (defaults to Socket::SOCK_STREAM).
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(path, type = Socket::SOCK_STREAM, **options)
			@path = path
			
			begin
				address = Address.unix(path, type)
			rescue ArgumentError
				path = self.class.short_path_for(path)
				address = Address.unix(path, type)
			end
			
			super(address, **options)
		end
		
		# Get a string representation of the UNIX endpoint.
		# @returns [String] A string representation showing the socket path.
		def to_s
			"unix:#{@path}"
		end
		
		# Get a detailed string representation of the UNIX endpoint.
		# @returns [String] A detailed string representation including the path.
		def inspect
			target_path = @address.unix_path
			
			if @path == target_path
				"\#<#{self.class} path=#{@path.inspect}>"
			else
				"\#<#{self.class} path=#{@path.inspect} target=#{target_path.inspect}>"
			end
		end
		
		# @attribute [String] The path to the UNIX socket.
		def path
			@path
		end
		
		# Check if a symlink is used for this endpoint.
		#
		# A symlink is created when the original path exceeds the system's maximum UNIX socket path length and a shorter temporary path is used for the actual socket.
		#
		# @returns [Boolean] True if the original path differs from the socket path, indicating a symlink is required.
		def symlink?
			File.symlink?(@path)
		end
		
		# Check if the socket is currently bound and accepting connections.
		# @returns [Boolean] True if the socket is bound and accepting connections, false otherwise.
		def bound?
			self.connect do
				return true
			end
		rescue Errno::ECONNREFUSED
			return false
		rescue Errno::ENOENT
			return false
		end
		
		# Bind the UNIX socket, handling stale socket files.
		# @yields {|socket| ...} If a block is given, yields the bound socket.
		# 	@parameter socket [Socket] The bound socket.
		# @returns [Array(Socket)] The bound socket.
		# @raises [Errno::EADDRINUSE] If the socket is still in use by another process.
		def bind(...)
			result = super
			create_symlink_if_required!
			return result
		rescue Errno::EADDRINUSE
			# If you encounter EADDRINUSE from `bind()`, you can check if the socket is actually accepting connections by attempting to `connect()` to it. If the socket is still bound by an active process, the connection will succeed. Otherwise, it should be safe to `unlink()` the path and try again.
			if !bound?
				unlink_stale_paths!
				retry
			else
				raise
			end
		end
		
		# Read a symlink, returning nil if the file does not exist.
		#
		# @parameter path [String] The path to the symlink.
		# @returns [String | Nil] The target of the symlink, or nil if the file does not exist.
		private def read_link(path)
			File.readlink(path)
		rescue # Errno::ENOENT, Errno::EINVAL
			# The file is not a symlink, or the symlink is invalid.
			nil
		end
		
		# Create a symlink to the actual socket path if required.
		private def create_symlink_if_required!
			# Ensure the directory exists:
			FileUtils.mkdir_p(File.dirname(@path))
			
			# This is the actual path we want to use for the socket:
			target_path = @address.unix_path
			
			# If it's the same as the original path, we are done:
			return if @path == target_path
			
			# Otherwise, we need might need to create a symlink:
			if read_link(target_path) == @path
				return
			else
				File.unlink(@path) rescue nil
			end
			
			# Create symlink at @path (original long path) pointing to target_path (short socket path)
			File.symlink(target_path, @path)
		end
		
		private def unlink_stale_paths!
			File.unlink(@path) rescue nil
			
			target_path = @address.unix_path
			
			if @path != target_path
				File.unlink(target_path) rescue nil
			end
		end
	end
	
	# @parameter path [String]
	# @parameter type Socket type
	# @parameter options keyword arguments passed through to {UNIXEndpoint#initialize}
	#
	# @returns [UNIXEndpoint]
	def self.unix(path = "", type = ::Socket::SOCK_STREAM, **options)
		UNIXEndpoint.new(path, type, **options)
	end
end
