# Getting Started

This guide explains how to use `io-stream` to add efficient buffering to Ruby IO objects.

## Overview

`io-stream` provides a buffered stream wrapper for any IO-like object in Ruby. It wraps standard Ruby IO instances (files, sockets, pipes) and adds buffering for both reading and writing operations, significantly improving performance for applications that perform many small reads or writes.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add io-stream
~~~

## Core Concepts

### Buffered Streams

`io-stream` provides buffering through the {IO::Stream::Buffered} class, which wraps any IO object. Buffering reduces the number of system calls by accumulating data in memory before actually reading from or writing to the underlying IO.

### Read and Write Buffers

The stream maintains separate buffers for reading and writing:

- **Read buffer**: Accumulates data from the underlying IO, allowing multiple small reads without system calls
- **Write buffer**: Accumulates data to write, flushing to the underlying IO only when the buffer is full or explicitly flushed

## Usage

### Wrapping an IO Object

You can wrap any IO-like object using {IO::Stream}:

~~~ ruby
require 'io/stream'

# Wrap a file
file = File.open("data.txt", "w+")
stream = IO::Stream(file)

# Wrap a socket
require 'socket'
socket = TCPSocket.new("example.com", 80)
stream = IO::Stream(socket)
~~~

### Opening Files Directly

You can also open files directly as buffered streams:

~~~ ruby
require 'io/stream'

# Open a file for reading
stream = IO::Stream::Buffered.open("data.txt", "r")
data = stream.read
stream.close

# Open with a block (auto-closes)
IO::Stream::Buffered.open("data.txt", "w") do |stream|
	stream.write("Hello, World!")
	stream.flush
end
~~~

### Reading Data

The {IO::Stream::Readable} module provides various methods for reading:

~~~ ruby
require 'io/stream'

IO::Stream::Buffered.open("data.txt", "r") do |stream|
	# Read entire stream
	content = stream.read
	
	# Read specific number of bytes
	chunk = stream.read(1024)
	
	# Read a line
	line = stream.gets
	
	# Read all lines
	lines = stream.readlines
	
	# Check for end of stream
	if stream.eof?
		puts "Reached end of file"
	end
end
~~~

### Writing Data

The {IO::Stream::Writable} module provides methods for writing:

~~~ ruby
require 'io/stream'

IO::Stream::Buffered.open("output.txt", "w") do |stream|
	# Write data (buffered)
	stream.write("Hello, ")
	stream.write("World!")
	
	# Write with automatic newline
	stream.puts("This is a line")
	
	# Flush buffer to ensure data is written
	stream.flush
end
~~~

## Important Behaviors

### Automatic Flushing

The write buffer automatically flushes when:

- The buffer size reaches the minimum write size (default: 64KB).
- You call {IO::Stream::Writable#puts} (always flushes immediately).
- You call {IO::Stream::Writable#flush} explicitly.
- The stream is closed.

### Manual Flushing

For applications that need precise control over when data is written:

~~~ ruby
stream.write("Important data")
stream.flush  # Ensure data is written immediately
~~~

### Buffer Sizes

You can customize buffer sizes when creating streams:

~~~ ruby
# Smaller buffer for interactive applications
stream = IO::Stream::Buffered.new(io, minimum_write_size: 4096)

# Larger buffer for bulk operations
stream = IO::Stream::Buffered.new(io, minimum_write_size: 256 * 1024)
~~~
