# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/pool/controller"

Traces::Provider(Async::Pool::Controller) do
	def create_resource(...)
		attributes = {
			concurrency: @guard.limit,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.pool.create", attributes: attributes){super}
	end
	
	def drain(...)
		attributes = {
			size: @resources.size,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.pool.drain", attributes: attributes){super}
	end
	
	def acquire(...)
		attributes = {
			size: @resources.size,
			limit: @limit,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.pool.acquire", attributes: attributes){super}
	end
	
	def release(...)
		attributes = {
			size: @resources.size,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.pool.release", attributes: attributes){super}
	end
	
	def retire(...)
		attributes = {
			size: @resources.size,
		}
		
		attributes.merge!(@tags) if @tags
		
		Traces.trace("async.pool.retire", attributes: attributes){super}
	end
end
