# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "console/logger"

require "async/notification"
require "async/semaphore"

module Async
	module Pool
		# The basic interface required by a pool resource.
		class Resource
			# Constructs a resource.
			def self.call
				self.new
			end
			
			# Create a new resource.
			#
			# @parameter concurrency [Integer] The concurrency of this resource.
			def initialize(concurrency = 1)
				@concurrency = concurrency
				@closed = false
				@count = 0
			end
			
			# @attr [Integer] The concurrency of this resource, 1 (singleplex) or more (multiplex).
			attr :concurrency
			
			# @attr [Integer] The number of times this resource has been used.
			attr :count
			
			# Whether this resource can be acquired.
			# @return [Boolean] whether the resource can actually be used.
			def viable?
				!@closed
			end
			
			# Whether the resource has been closed by the user.
			# @return [Boolean] whether the resource has been closed or has failed.
			def closed?
				@closed
			end
			
			# Close the resource explicitly, e.g. the pool is being closed.
			def close
				@closed = true
			end
			
			# Whether this resource can be reused. Used when releasing resources back into the pool.
			def reusable?
				!@closed
			end
		end
	end
end
