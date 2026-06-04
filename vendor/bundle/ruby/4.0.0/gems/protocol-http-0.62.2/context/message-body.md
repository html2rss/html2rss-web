# Message Body

This guide explains how to work with HTTP request and response message bodies using `Protocol::HTTP::Body` classes.

## Overview

HTTP message bodies represent the actual (often stateful) data content of requests and responses. `Protocol::HTTP` provides a rich set of body classes for different use cases, from simple string content to streaming data and file serving.

All body classes inherit from {ruby Protocol::HTTP::Body::Readable}, which provides a consistent interface for reading data in chunks. Bodies can be:
- **Buffered**: All content stored in memory.
- **Streaming**: Content generated or read on-demand.
- **File-based**: Content read directly from files.
- **Transforming**: Content modified as it flows through e.g. compression, encryption.

## Core Body Interface

Every body implements the `Readable` interface:

``` ruby
# Read the next chunk of data:
chunk = body.read
# => "Hello" or nil when finished

# Check if body has data available without blocking:
body.ready?  # => true/false

# Check if body is empty:
body.empty?  # => true/false

# Close the body and release resources:
body.close

# Iterate through all chunks: 
body.each do |chunk|
	puts chunk
end

# Read entire body into a string:
content = body.join
```

## Buffered Bodies

Use {ruby Protocol::HTTP::Body::Buffered} for content that's fully loaded in memory:

``` ruby
# Create from string:
body = Protocol::HTTP::Body::Buffered.new(["Hello", " ", "World"])

# Create from array of strings:
chunks = ["First chunk", "Second chunk", "Third chunk"]
body = Protocol::HTTP::Body::Buffered.new(chunks)

# Wrap various types automatically:
body = Protocol::HTTP::Body::Buffered.wrap("Simple string")
body = Protocol::HTTP::Body::Buffered.wrap(["Array", "of", "chunks"])

# Access properties:
body.length      # => 13 (total size in bytes)
body.empty?      # => false
body.ready?      # => true (always ready)

# Reading:
first_chunk = body.read    # => "Hello"
second_chunk = body.read   # => " "
third_chunk = body.read    # => "World"
fourth_chunk = body.read   # => nil (finished)

# Rewind to beginning:
body.rewind
body.read  # => "Hello" (back to start)
```

### Buffered Body Features

``` ruby
# Check if rewindable:
body.rewindable?  # => true for buffered bodies

# Get all content as single string:
content = body.join  # => "Hello World"

# Convert to array of chunks:
chunks = body.to_a   # => ["Hello", " ", "World"]

# Write additional chunks:
body.write("!")
body.join  # => "Hello World!"

# Clear all content:
body.clear
body.empty?  # => true
```

## File Bodies

Use {ruby Protocol::HTTP::Body::File} for serving files efficiently:

``` ruby
require "protocol/http/body/file"

# Open a file:
body = Protocol::HTTP::Body::File.open("/path/to/file.txt")

# Create from existing File object:
file = File.open("/path/to/image.jpg", "rb")
body = Protocol::HTTP::Body::File.new(file)

# Serve partial content (ranges):
range = 100...200  # bytes 100-199
body = Protocol::HTTP::Body::File.new(file, range)

# Properties:
body.length      # => file size or range size
body.empty?      # => false (unless zero-length file)
body.ready?      # => false (may block when reading)

# File bodies read in chunks automatically:
body.each do |chunk|
	# Process each chunk (typically 64KB)
	puts "Read #{chunk.bytesize} bytes"
end
```

### File Body Range Requests

``` ruby
# Serve specific byte ranges (useful for HTTP range requests):
file = File.open("large_video.mp4", "rb")

# First 1MB:
partial_body = Protocol::HTTP::Body::File.new(file, 0...1_048_576)

# Custom block size for reading:
body = Protocol::HTTP::Body::File.new(file, block_size: 8192)  # 8KB chunks
```

## Writable Bodies

Use {ruby Protocol::HTTP::Body::Writable} for dynamic content generation:

``` ruby
require "protocol/http/body/writable"

# Create a writable body:
body = Protocol::HTTP::Body::Writable.new

# Write data in another thread/fiber:
Thread.new do
	body.write("First chunk\n")
	sleep 0.1
	body.write("Second chunk\n")
	body.write("Final chunk\n")
	body.close_write  # Signal no more data
end

# Read from main thread:
body.each do |chunk|
	puts "Received: #{chunk}"
end
# Output:
# Received: First chunk
# Received: Second chunk  
# Received: Final chunk
```

### Writable Body with Backpressure

``` ruby
# Use SizedQueue to limit buffering:
queue = Thread::SizedQueue.new(10)  # Buffer up to 10 chunks
body = Protocol::HTTP::Body::Writable.new(queue: queue)

# Writing will block if queue is full:
body.write("chunk 1")
# ... write up to 10 chunks before blocking
```

## Streaming Bodies

Use {ruby Protocol::HTTP::Body::Streamable} for computed content:

``` ruby
require "protocol/http/body/streamable"

# Generate content dynamically:
body = Protocol::HTTP::Body::Streamable.new do |output|
	10.times do |i|
		output.write("Line #{i}\n")
		# Could include delays, computation, database queries, etc.
	end
end

# Content is generated as it's read:
body.each do |chunk|
	puts "Got: #{chunk}"
end
```

## Stream Bodies (IO Wrapper)

Use {ruby Protocol::HTTP::Body::Stream} to wrap IO-like objects:

``` ruby
require "protocol/http/body/stream"

# Wrap an IO object:
io = StringIO.new("Hello\nWorld\nFrom\nStream")
body = Protocol::HTTP::Body::Stream.new(io)

# Read line by line:
line1 = body.gets    # => "Hello\n"
line2 = body.gets    # => "World\n"

# Read specific amounts:
data = body.read(5)  # => "From\n"

# Read remaining data:
rest = body.read     # => "Stream"
```

## Body Transformations

### Compression Bodies

``` ruby
require "protocol/http/body/deflate"
require "protocol/http/body/inflate"

# Compress a body:
original = Protocol::HTTP::Body::Buffered.new(["Hello World"])
compressed = Protocol::HTTP::Body::Deflate.new(original)

# Decompress a body:
decompressed = Protocol::HTTP::Body::Inflate.new(compressed)
content = decompressed.join  # => "Hello World"
```

### Wrapper Bodies

Create custom body transformations:

``` ruby
require "protocol/http/body/wrapper"

class UppercaseBody < Protocol::HTTP::Body::Wrapper
	def read
		if chunk = super
			chunk.upcase
		end
	end
end

# Use the wrapper:
original = Protocol::HTTP::Body::Buffered.wrap("hello world")
uppercase = UppercaseBody.new(original)
content = uppercase.join  # => "HELLO WORLD"
```

## Life-cycle

### Initialization

Bodies are typically initialized with the data they need to process. For example:

``` ruby
body = Protocol::HTTP::Body::Buffered.wrap("Hello World")
```

### Reading

Once initialized, bodies can be read in chunks:

``` ruby
body.each do |chunk|
	puts "Read #{chunk.bytesize} bytes"
end
```

### Closing

It's important to close bodies when done to release resources:

``` ruby
begin
	# ... read from the body ...
rescue => error
	# Ignore.
ensure
	# The body should always be closed:
	body.close(error)
end
```

## Advanced Usage

### Rewindable Bodies

Make any body rewindable by buffering:

``` ruby
require "protocol/http/body/rewindable"

# Wrap a non-rewindable body:
file_body = Protocol::HTTP::Body::File.open("data.txt")
rewindable = Protocol::HTTP::Body::Rewindable.new(file_body)

# Read some data:
first_chunk = rewindable.read

# Rewind and read again:
rewindable.rewind
same_chunk = rewindable.read  # Same as first_chunk
```

### Head Bodies (Response without content)

For HEAD requests that need content-length but no body:

``` ruby
require "protocol/http/body/head"

# Create head body from another body:
original = Protocol::HTTP::Body::File.open("large_file.zip")
head_body = Protocol::HTTP::Body::Head.for(original)

head_body.length  # => size of original file
head_body.read    # => nil (no actual content)
head_body.empty?  # => true
```
