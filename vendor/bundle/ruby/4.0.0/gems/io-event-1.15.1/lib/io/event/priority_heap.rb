# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021, by Wander Hillen.
# Copyright, 2021-2026, by Samuel Williams.

class IO
	module Event
		# A priority queue implementation using a standard binary minheap. It uses straight comparison
		# of its contents to determine priority.
		# See <https://en.wikipedia.org/wiki/Binary_heap> for explanations of the main methods.
		class PriorityHeap
			# Initializes the heap.
			def initialize
				# The heap is represented with an array containing a binary tree. See
				# https://en.wikipedia.org/wiki/Binary_heap#Heap_implementation for how this array
				# is built up.
				@contents = []
			end
			
			# @returns [Object | Nil] the smallest element in the heap without removing it, or nil if the heap is empty.
			def peek
				@contents[0]
			end
			
			# @returns [Integer] the number of elements in the heap.
			def size
				@contents.size
			end
			
			# @returns [Boolean] true if the heap is empty, false otherwise.
			def empty?
				@contents.empty?
			end
			
			# Removes and returns the smallest element in the heap, or nil if the heap is empty.
			#
			# @returns [Object | Nil] The smallest element in the heap, or nil if the heap is empty.
			def pop
				# If the heap is empty:
				if @contents.empty?
					return nil
				end
				
				# If we have only one item, no swapping is required:
				if @contents.size == 1
					return @contents.pop
				end
				
				# Take the root of the tree:
				value = @contents[0]
				
				# Remove the last item in the tree:
				last = @contents.pop
				
				# Overwrite the root of the tree with the item:
				@contents[0] = last
				
				# Bubble it down into place:
				bubble_down(0)
				
				# validate!
				
				return value
			end
			
			# Add a new element to the heap, then rearrange elements until the heap invariant is true again.
			#
			# @parameter element [Object] The element to add to the heap.
			def push(element)
				# Insert the item at the end of the heap:
				@contents.push(element)
				
				# Bubble it up into position:
				bubble_up(@contents.size - 1)
				
				# validate!
				
				return self
			end
			
			# Add multiple elements to the heap efficiently in O(n) time.
			# This is more efficient than calling push multiple times (O(n log n)).
			#
			# @parameter elements [Array] The elements to add to the heap.
			# @returns [self] Returns self for method chaining.
			def concat(elements)
				return self if elements.empty?
				
				# Add all elements to the array without maintaining heap property - O(n)
				@contents.concat(elements)
				
				# Rebuild the heap property for the entire array - O(n)
				heapify!
				
				return self
			end
			
			# Empties out the heap, discarding all elements
			def clear!
				@contents = []
			end
			
			# Remove a specific element from the heap.
			#
			# O(n) where n is the number of elements in the heap.
			#
			# @parameter element [Object] The element to remove.
			# @returns [Object | Nil] The removed element, or nil if not found.
			def delete(element)
				# Find the index of the element - O(n) linear search
				index = @contents.index(element)
				return nil unless index
				
				# If it's the last element, just remove it
				if index == @contents.size - 1
					return @contents.pop
				end
				
				# Store the value we're removing
				removed_value = @contents[index]
				
				# Replace with the last element
				last = @contents.pop
				@contents[index] = last
				
				# Restore heap property - might need to bubble up or down
				if index > 0 && @contents[index] < @contents[(index - 1) / 2]
					# New element is smaller than parent, bubble up
					bubble_up(index)
				else
					# New element might be larger than children, bubble down
					bubble_down(index)
				end
				
				# validate!
				
				return removed_value
			end
			
			# Remove elements matching the given block condition by rebuilding the heap.
			#
			# This is more efficient than multiple delete operations when removing many elements.
			#
			# O(n) where n is the number of elements in the heap.
			#
			# @yields [Object] Each element in the heap for testing
			# @returns [Integer] The number of elements removed
			def delete_if
				return enum_for(:delete_if) unless block_given?
				
				original_size = @contents.size
				
				# Filter out elements that match the condition - O(n)
				@contents.reject!{|element| yield(element)}
				
				# If we removed elements, rebuild the heap - O(n)
				if @contents.size < original_size
					heapify!
				end
				
				# Return number of elements removed
				original_size - @contents.size
			end
			
			# Validate the heap invariant. Every element except the root must not be smaller than its parent element. Note that it MAY be equal.
			def valid?
				# Notice we skip index 0 on purpose, because it has no parent:
				(1..(@contents.size - 1)).all?{|index| @contents[index] >= @contents[(index - 1) / 2]}
			end
			
			private
			
			# Rebuild the heap property from an arbitrary array in O(n) time.
			# Uses bottom-up heapify algorithm starting from the last non-leaf node.
			def heapify!
				return if @contents.size <= 1
				
				# Start from the last non-leaf node and work backwards to root:
				last_non_leaf_index = (@contents.size / 2) - 1
				last_non_leaf_index.downto(0) do |index|
					bubble_down(index)
				end
				
				# validate!
			end
			
			# Left here for reference, but unused.
			# def swap(i, j)
			# 	@contents[i], @contents[j] = @contents[j], @contents[i]
			# end
			
			def bubble_up(index)
				parent_index = (index - 1) / 2 # watch out, integer division!
				
				while index > 0 && @contents[index] < @contents[parent_index]
					# If the node has a smaller value than its parent, swap these nodes to uphold the minheap invariant and update the index of the 'current' node. If the node is already at index 0, we can also stop because that is the root of the heap.
					# swap(index, parent_index)
					@contents[index], @contents[parent_index] = @contents[parent_index], @contents[index]
					
					index = parent_index
					parent_index = (index - 1) / 2 # watch out, integer division!
				end
			end
			
			def bubble_down(index)
				swap_value = 0
				swap_index = nil
				
				while true
					left_index = (2 * index) + 1
					left_value = @contents[left_index]
					
					if left_value.nil?
						# This node has no children so it can't bubble down any further. We're done here!
						return
					end
					
					# Determine which of the child nodes has the smallest value:
					right_index = left_index + 1
					right_value = @contents[right_index]
					
					if right_value.nil? or right_value > left_value
						swap_value = left_value
						swap_index = left_index
					else
						swap_value = right_value
						swap_index = right_index
					end
					
					if @contents[index] < swap_value
						# No need to swap, the minheap invariant is already satisfied:
						return
					else
						# At least one of the child node has a smaller value than the current node, swap current node with that child and update current node for if it might need to bubble down even further:
						# swap(index, swap_index)
						@contents[index], @contents[swap_index] = @contents[swap_index], @contents[index]
						
						index = swap_index
					end
				end
			end
		end
	end
end
