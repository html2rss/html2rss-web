# Getting Started

This guide explains how to use `io-event` for non-blocking IO.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add io-event
~~~

## Core Concepts

`io-event` has several core concepts:

- A {ruby IO::Event::Selector} implementation which provides the primitive operations for implementation an event loop.
- A {ruby IO::Event::Debug::Selector} which adds extra validations and checks at the expense of performance. You should generally use this during tests.

## Basic Event Loop

This example shows how to perform a blocking operation 

```ruby
require "fiber"
require "io/event"

selector = IO::Event::Selector.new(Fiber.current)
input, output = IO.pipe

writer = Fiber.new do
	output.write("Hello World")
	output.close
end

reader = Fiber.new do
	selector.io_wait(Fiber.current, input, IO::READABLE)
	pp read: input.read
end

# The reader will be blocked until the IO has data available:
reader.transfer

# Write some data to the pipe and close the writing end:
writer.transfer

selector.select(1)

# Results in:
# {:read=>"Hello World"}
```

## Debugging

The {ruby IO::Event::Debug::Selector} class adds extra validations and checks at the expense of performance. It can also log all operations. You can use this by setting the following environment variables:

```shell
$ IO_EVENT_SELECTOR_DEBUG=y IO_EVENT_SELECTOR_DEBUG_LOG=/dev/stderr bundle exec ./my_script.rb
```

The format of the log is subject to change, but it may be useful for debugging.
