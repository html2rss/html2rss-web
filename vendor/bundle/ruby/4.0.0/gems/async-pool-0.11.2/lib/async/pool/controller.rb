# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2020, by Simon Perepelitsa.
# Copyright, 2024, by Thomas Morgan.
# Copyright, 2025, by Jean Boussier.
# Copyright, 2026, by William T. Nelson.

require "console/logger"

require "async"
require "async/semaphore"

require "thread"

module Async
	module Pool
		# A resource pool controller.
		class Controller
			# Create a new resource pool, using the given block to create new resources.
			def self.wrap(**options, &block)
				self.new(block, **options)
			end
			
			# Create a new resource pool.
			#
			# @parameter constructor [Proc] A block which creates a new resource.
			# @parameter limit [Integer | Nil] The maximum number of resources that this pool can have at any given time. If nil, the pool can have an unlimited number of resources.
			# @parameter concurrency [Integer] The maximum number of concurrent tasks that can be creating a new resource. Defaults to 1 to ensure the pool limit is enforced. Higher values may result in more resources being created than the limit under high load.
			# @parameter policy [Policy] The pool policy.
			def initialize(constructor, limit: nil, concurrency: 1, policy: nil, tags: nil)
				@constructor = constructor
				@limit = limit
				
				# This semaphore is used to limit the number of concurrent tasks which are creating new resources.
				@guard = Async::Semaphore.new(concurrency)
				
				@policy = policy
				@gardener = nil
				
				@tags = tags
				
				# All available resources:
				@resources = {}
				
				# Resources which may be available to be acquired:
				# This list may contain false positives, or resources which were okay but have since entered a state which is unusuable.
				@available = []
				
				# Used to signal when a resource has been released:
				@mutex = Thread::Mutex.new
				@condition = Thread::ConditionVariable.new
			end
			
			# @attribute [Proc] The constructor used to create new resources.
			attr :constructor
			
			# @attribute [Integer] The maximum number of resources that this pool can have at any given time.
			attr_accessor :limit
			
			# Generate a human-readable representation of the pool.
			def to_s
				if @resources.empty?
					"\#<#{self.class}(#{usage_string})>"
				else
					"\#<#{self.class}(#{usage_string}) #{availability_summary.join(';')}>"
				end
			end
			
			# Generate a JSON representation of the pool.
			def as_json(...)
				{
					limit: @limit,
					concurrency: @guard.limit,
					usage: @resources.size,
					availability_summary: self.availability_summary,
				}
			end
			
			# Generate a JSON representation of the pool.
			def to_json(...)
				as_json.to_json(...)
			end
			
			# @attribute [Integer] The maximum number of concurrent tasks that can be creating a new resource.
			def concurrency
				@guard.limit
			end
			
			# Set the maximum number of concurrent tasks that can be creating a new resource.
			def concurrency= value
				@guard.limit = value
			end
			
			# @attribute [Policy] The pool policy.
			attr_accessor :policy
			
			# @attribute [Hash(Resource, Integer)] all allocated resources, and their associated usage.
			attr :resources
			
			# @attribute [Array(String)] The name of the pool.
			attr_accessor :tags
			
			# The number of resources in the pool.
			def size
				@resources.size
			end
			
			# Whether the pool has any active resources.
			def active?
				!@resources.empty?
			end
			
			# Whether there are resources which are currently in use.
			def busy?
				@resources.collect do |_, usage|
					return true if usage > 0
				end
				
				return false
			end
			
			# Whether there are available resources, i.e. whether {#acquire} can reuse an existing resource.
			def available?
				@available.any?
			end
			
			# Wait until a pool resource has been freed.
			# @deprecated Use {wait_until_free} instead.
			def wait
				@mutex.synchronize do
					@condition.wait(@mutex)
				end
			end
			
			# Wait until the pool is not busy (no resources in use).
			def wait_until_free
				@mutex.synchronize do
					if busy?
						yield self if block_given?
						
						# Wait until the pool is not busy:
						@condition.wait(@mutex) while busy?
					end
				end
			end
			
			# Whether the pool is empty.
			def empty?
				@resources.empty?
			end
			
			# Acquire a resource from the pool. If a block is provided, the resource will be released after the block has been executed.
			def acquire
				resource = wait_for_resource
				
				return resource unless block_given?
				
				begin
					yield resource
				ensure
					release(resource)
				end
			end
			
			# Make the resource resources and let waiting tasks know that there is something resources.
			def release(resource)
				processed = false
				
				# A resource that is not good should also not be reusable.
				if resource.reusable?
					processed = reuse(resource)
				end
				
				# @policy.released(self, resource)
			ensure
				retire(resource) unless processed
			end
			
			# Drain the pool, closing all resources.
			def drain
				Console.debug(self, "Draining pool...", size: @resources.size)
				
				# Enumerate all existing resources and retire them:
				while resource = acquire_existing_resource
					retire(resource)
				end
			end
			
			# Drain the pool, clear all resources, and stop the gardener.
			def close
				self.drain
				
				@available.clear
				@gardener&.stop
			end
			
			# Retire (and close) all unused resources. If a block is provided, it should implement the desired functionality for unused resources.
			# @parameter retain [Integer] the minimum number of resources to retain.
			# @yields {|resource| ...} Any unused resource.
			def prune(retain = 0)
				unused = []
				
				# This code must not context switch:
				@resources.each do |resource, usage|
					if usage.zero?
						unused << resource
					end
				end
				
				# It's okay for this to context switch:
				unused.each do |resource|
					if block_given?
						yield resource
					else
						retire(resource)
					end
					
					break if @resources.size <= retain
				end
				
				# Update availability list:
				@available.clear
				@resources.each do |resource, usage|
					if usage < resource.concurrency and resource.reusable?
						@available << resource
					end
				end
				
				return unused.size
			end
			
			# Retire a specific resource.
			def retire(resource)
				Console.debug(self){"Retire #{resource}"}
				
				return false unless @resources.delete(resource)
				
				resource.close
				
				@mutex.synchronize{@condition.broadcast}
				
				return true
			end
			
			protected
			
			def start_gardener
				return if @gardener
				
				@gardener = true
				
				Async(transient: true, annotation: "#{self.class} Gardener") do |task|
					@gardener = task
					
					while true
						@policy&.call(self)
						self.wait
					end
				ensure
					@gardener = nil
					self.close
				end
			end
			
			def usage_string
				"#{@resources.size}/#{@limit || '∞'}"
			end
			
			def availability_summary
				@resources.collect do |resource, usage|
					"#{usage}/#{resource.concurrency}#{resource.viable? ? nil : '*'}/#{resource.count}"
				end
			end
			
			# def usage
			# 	@resources.count{|resource, usage| usage > 0}
			# end
			#
			# def free
			# 	@resources.count{|resource, usage| usage == 0}
			# end
			
			def reuse(resource)
				Console.debug(self){"Reuse #{resource}"}
				
				usage = @resources[resource]
				
				if usage.nil?
					return false
				end
				
				if usage.zero?
					raise "Trying to reuse unacquired resource: #{resource}!"
				end
				
				# If the resource was fully utilized, it now becomes available:
				if usage == resource.concurrency
					@available.push(resource)
				end
				
				@resources[resource] = usage - 1
				
				@mutex.synchronize{@condition.broadcast}
				
				return true
			end
			
			def wait_for_resource
				# If we fail to create a resource (below), we will end up waiting for one to become resources.
				until resource = available_resource
					@mutex.synchronize{@condition.wait(@mutex)}
				end
				# Be careful not to context switch or fail here.
				return resource
			end
			
			# @returns [Object] A new resource in a "used" state.
			def create_resource
				self.start_gardener
				
				# This might return nil, which means creating the resource failed.
				if resource = @constructor.call
					@resources[resource] = 1
					
					# Make the resource available if it can be used multiple times:
					if resource.concurrency > 1
						@available.push(resource)
					end
				end
				
				# @policy.created(self, resource)
				
				return resource
			end
			
			# @returns [Object] An existing resource in a "used" state.
			def available_resource
				resource = nil
				
				@guard.acquire do
					resource = acquire_or_create_resource
				end
				
				return resource
			rescue Exception
				reuse(resource) if resource
				raise
			end
			
			private
			
			# Acquire an existing resource with zero usage.
			# If there are resources that are in use, wait until they are released.
			def acquire_existing_resource
				while @resources.any?
					@resources.each do |resource, usage|
						if usage == 0
							return resource
						end
					end
					@mutex.synchronize{@condition.wait(@mutex)}
				end
				# Only when the pool has been completely drained, return nil:
				return nil
			end
			
			def acquire_or_create_resource
				while resource = @available.last
					if usage = @resources[resource] and usage < resource.concurrency
						if resource.viable?
							usage = (@resources[resource] += 1)
							
							if usage == resource.concurrency
								# The resource is used up to it's limit:
								@available.pop
							end
							
							return resource
						else
							retire(resource)
							@available.pop
						end
					else
						# The resource has been removed already, so skip it and remove it from the availability list.
						@available.pop
					end
				end
				
				if @limit.nil? or @resources.size < @limit
					Console.debug(self){"No available resources, allocating new one..."}
					
					return create_resource
				end
			end
		end
	end
end
