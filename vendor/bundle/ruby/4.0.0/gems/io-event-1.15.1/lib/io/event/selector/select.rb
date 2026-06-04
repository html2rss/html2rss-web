# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2026, by Samuel Williams.
# Copyright, 2023, by Math Ieu.

require_relative "../interrupt"

module IO::Event
	module Selector
		# A pure-Ruby implementation of the event selector.
		class Select
			# Initialize the selector with the given event loop fiber.
			def initialize(loop)
				@loop = loop
				
				@waiting = Hash.new.compare_by_identity
				
				# Flag indicating whether the selector is currently blocked in a system call.
				# Set to true when blocked in ::IO.select, false otherwise.
				# Used by wakeup() to determine if an interrupt signal is needed.
				@blocked = false
				
				@ready = Queue.new
				@interrupt = Interrupt.attach(self)
				
				@idle_duration = 0.0
			end
			
			# @attribute [Fiber] The event loop fiber.
			attr :loop
			
			# @attribute [Float] This is the amount of time the event loop was idle during the last select call.
			attr :idle_duration
			
			# Wake up the event loop if it is currently sleeping.
			def wakeup
				if @blocked
					@interrupt.signal
					
					return true
				end
				
				return false
			end
			
			# Close the selector and release any resources.
			def close
				@interrupt.close
				
				@loop = nil
				@waiting = nil
			end
			
			Optional = Struct.new(:fiber) do
				def transfer(*arguments)
					fiber&.transfer(*arguments)
				end
				
				def alive?
					fiber&.alive?
				end
				
				def nullify
					self.fiber = nil
				end
			end
			
			# Transfer from the current fiber to the event loop.
			def transfer
				@loop.transfer
			end
			
			# Transfer from the current fiber to the specified fiber. Put the current fiber into the ready list.
			def resume(fiber, *arguments)
				optional = Optional.new(Fiber.current)
				@ready.push(optional)
				
				fiber.transfer(*arguments)
			ensure
				optional.nullify
			end
			
			# Yield from the current fiber back to the event loop. Put the current fiber into the ready list.
			def yield
				optional = Optional.new(Fiber.current)
				@ready.push(optional)
				
				@loop.transfer
			ensure
				optional.nullify
			end
			
			# Append the given fiber into the ready list.
			def push(fiber)
				@ready.push(fiber)
			end
			
			# Transfer to the given fiber and raise an exception. Put the current fiber into the ready list.
			def raise(fiber, *arguments, **options)
				optional = Optional.new(Fiber.current)
				@ready.push(optional)
				
				fiber.raise(*arguments, **options)
			ensure
				optional.nullify
			end
			
			# @returns [Boolean] Whether the ready list is not empty, i.e. there are fibers ready to be resumed.
			def ready?
				!@ready.empty?
			end
			
			Waiter = Struct.new(:fiber, :events, :tail) do
				def alive?
					self.fiber&.alive?
				end
				
				# Dispatch the given events to the list of waiting fibers. If the fiber was not waiting for the given events, it is reactivated by calling the given block.
				def dispatch(events, &reactivate)
					# We capture the tail here, because calling reactivate might modify it:
					tail = self.tail
					
					if fiber = self.fiber
						if fiber.alive?
							revents = events & self.events
							if revents.zero?
								reactivate.call(self)
							else
								self.fiber = nil
								fiber.transfer(revents)
							end
						else
							self.fiber = nil
						end
					end
					
					tail&.dispatch(events, &reactivate)
				end
				
				def invalidate
					self.fiber = nil
				end
				
				def each(&block)
					if fiber = self.fiber
						yield fiber, self.events
					end
					
					self.tail&.each(&block)
				end
			end
			
			# Wait for the given IO to become readable or writable.
			#
			# @parameter fiber [Fiber] The fiber that is waiting.
			# @parameter io [IO] The IO object to wait on.
			# @parameter events [Integer] The events to wait for.
			def io_wait(fiber, io, events)
				waiter = @waiting[io] = Waiter.new(fiber, events, @waiting[io])
				
				@loop.transfer
			ensure
				waiter&.invalidate
			end
			
			# Wait for multiple IO objects to become readable or writable.
			#
			# @parameter readable [Array(IO)] The list of IO objects to wait for readability.
			# @parameter writable [Array(IO)] The list of IO objects to wait for writability.
			# @parameter priority [Array(IO)] The list of IO objects to wait for priority events.
			def io_select(readable, writable, priority, timeout)
				Thread.new do
					IO.select(readable, writable, priority, timeout)
				end.value
			end
			
			EAGAIN = -Errno::EAGAIN::Errno
			EWOULDBLOCK = -Errno::EWOULDBLOCK::Errno
			
			# Whether the given error code indicates that the operation should be retried.
			protected def again?(errno)
				errno == EAGAIN or errno == EWOULDBLOCK
			end
			
			# Read from the given IO to the buffer.
			#
			# @parameter length [Integer] The minimum number of bytes to read.
			# @parameter offset [Integer] The offset into the buffer to read to.
			def io_read(fiber, io, buffer, length, offset = 0)
				# Ensure offset is within the bounds of the buffer to avoid ArgumentError
				if offset > buffer.size
					return -Errno::EINVAL::Errno
				end
				
				total = 0
				
				Selector.nonblock(io) do
					while true
						result = Fiber.blocking{buffer.read(io, 0, offset)}
						
						if result < 0
							if length > 0 and again?(result)
								self.io_wait(fiber, io, IO::READABLE)
							else
								return result
							end
						elsif result == 0
							break
						else
							total += result
							break if total >= length
							offset += result
						end
					end
				end
				
				return total
			end
			
			# Write to the given IO from the buffer.
			#
			# @parameter length [Integer] The minimum number of bytes to write.
			# @parameter offset [Integer] The offset into the buffer to write from.
			def io_write(fiber, io, buffer, length, offset = 0)
				# Ensure offset is within the bounds of the buffer to avoid ArgumentError
				if offset > buffer.size
					return -Errno::EINVAL::Errno
				end
				
				total = 0
				
				Selector.nonblock(io) do
					while true
						result = Fiber.blocking{buffer.write(io, 0, offset)}
						
						if result < 0
							if length > 0 and again?(result)
								self.io_wait(fiber, io, IO::WRITABLE)
							else
								return result
							end
						elsif result == 0
							break result
						else
							total += result
							break if total >= length
							offset += result
						end
					end
				end
				
				return total
			end
			
			# Wait for a process to change state.
			#
			# @parameter fiber [Fiber] The fiber to resume after waiting.
			# @parameter pid [Integer] The process ID to wait for.
			# @parameter flags [Integer] Flags to pass to Process::Status.wait.
			# @returns [Process::Status] The status of the waited process.
			def process_wait(fiber, pid, flags)
				Thread.new do
					Process::Status.wait(pid, flags)
				end.value
			end
			
			private def pop_ready
				unless @ready.empty?
					count = @ready.size
					
					count.times do
						fiber = @ready.pop
						fiber.transfer if fiber.alive?
					end
					
					return true
				end
			end
			
			# Wait for IO events or a timeout.
			#
			# @parameter duration [Numeric | Nil] The maximum time to wait, or nil for no timeout.
			# @returns [Integer] The number of ready IO objects.
			def select(duration = nil)
				if pop_ready
					# If we have popped items from the ready list, they may influence the duration calculation, so we don't delay the event loop:
					duration = 0
				end
				
				readable = Array.new
				writable = Array.new
				priority = Array.new
				
				@waiting.delete_if do |io, waiter|
					if io.closed?
						# When an IO is closed, we silently drop it. Ruby 4's `rb_thread_io_close_interrupt` will take care of interrupting any fibers waiting on the closed IO, so we don't need to do anything here.
						true
					else
						waiter.each do |fiber, events|
							if (events & IO::READABLE) > 0
								readable << io
							end
							
							if (events & IO::WRITABLE) > 0
								writable << io
							end
							
							if (events & IO::PRIORITY) > 0
								priority << io
							end
						end
						
						false
					end
				end
				
				duration = 0 unless @ready.empty?
				error = nil
				
				if duration&.>(0)
					start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
				else
					@idle_duration = 0.0
				end
				
				# We need to handle interrupts on blocking IO. Every other implementation uses EINTR, but that doesn't work with `::IO.select` as it will retry the call on EINTR.
				Thread.handle_interrupt(::Exception => :on_blocking) do
					@blocked = true
					readable, writable, priority = ::IO.select(readable, writable, priority, duration)
				rescue ::Exception => error
					# Requeue below...
				ensure
					@blocked = false
					if start_time
						end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
						@idle_duration = end_time - start_time
					end
				end
				
				if error
					if error.is_a?(IOError) || error.is_a?(Errno::EBADF)
						# This can happen if an IO is closed while we're blocked in ::IO.select. Ruby 4's `rb_thread_io_close_interrupt` will take care of interrupting any fibers waiting on the closed IO, so we don't need to do anything here, except try again:
						return 0
					end
					
					# For all other errors (e.g. thread interrupts), re-queue on the scheduler thread:
					Thread.current.raise(error)
					return 0
				end
				
				ready = Hash.new(0).compare_by_identity
				
				readable&.each do |io|
					# Skip any IO that was closed/reused after IO.select returned - its fd number
					# may now belong to a different file, so resuming the waiter would be wrong:
					ready[io] |= IO::READABLE unless io.closed?
				end
				
				writable&.each do |io|
					ready[io] |= IO::WRITABLE unless io.closed?
				end
				
				priority&.each do |io|
					ready[io] |= IO::PRIORITY unless io.closed?
				end
				
				ready.each do |io, events|
					@waiting.delete(io).dispatch(events) do |waiter|
						# Re-schedule the waiting IO:
						waiter.tail = @waiting[io]
						@waiting[io] = waiter
					end
				end
				
				return ready.size
			end
		end
	end
end
