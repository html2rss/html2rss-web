# Brotli

Brotli is a Ruby implementation of the Brotli generic-purpose lossless
compression algorithm that compresses data using a combination of a modern
variant of the LZ77 algorithm, Huffman coding and 2nd order context modeling,
with a compression ratio comparable to the best currently available
general-purpose compression methods. It is similar in speed with deflate but
offers more dense compression.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'brotli'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install brotli

## Usage

### Basic Compression/Decompression

```ruby
require 'brotli'
compressed = Brotli.deflate(string)
decompressed = Brotli.inflate(compressed)
```

### Custom Dictionary Support

Brotli supports using custom dictionaries to improve compression ratio when you have repetitive data patterns:

```ruby
# Using a dictionary that contains common patterns in your data
dictionary = "common patterns in my data"
data = "This text contains common patterns in my data multiple times"

# Compress with dictionary
compressed = Brotli.deflate(data, dictionary: dictionary)

# Decompress with the same dictionary
decompressed = Brotli.inflate(compressed, dictionary: dictionary)
```

### Compression Options

```ruby
# Combine dictionary with other compression options
compressed = Brotli.deflate(data,
  dictionary: dictionary,
  quality: 11,        # 0-11, higher = better compression but slower
  mode: :text,        # :generic (default), :text, or :font
  lgwin: 22,          # window size (10-24)
  lgblock: 0          # block size (0 or 16-24)
)
```

### Streaming Compression with Writer

```ruby
# Basic usage
File.open('output.br', 'wb') do |file|
  writer = Brotli::Writer.new(file)
  writer.write(data)
  writer.close
end

# With dictionary
File.open('output.br', 'wb') do |file|
  writer = Brotli::Writer.new(file, dictionary: dictionary)
  writer.write(data)
  writer.close
end
```

### Streaming Decompression with Reader

```ruby
# Basic usage
File.open('output.br', 'rb') do |file|
  reader = Brotli::Reader.new(file)
  data = reader.read
  reader.close
end

# With dictionary
File.open('output.br', 'rb') do |file|
  reader = Brotli::Reader.new(file, dictionary: dictionary)
  data = reader.read
  reader.close
end
```

`Brotli::Reader` is the preferred API when you already have an IO-like input.
It handles incremental decompression for you, including small `read` and
`readpartial` calls.

### Low-level Streaming with Compressor and Decompressor

`Brotli::Writer` and `Brotli::Reader` are the preferred high-level streaming
interfaces. `Brotli::Compressor` and `Brotli::Decompressor` are lower-level
primitives intended for integrations which already manage their own buffering
and chunk boundaries.

Use `Brotli::Writer` and `Brotli::Reader` when you have an IO-like stream and
want Brotli to handle the streaming lifecycle for you.

Use `Brotli::Compressor` and `Brotli::Decompressor` when your application
already owns the buffering model, for example when working with framed
protocols, event loops, chunked transports, or custom body transcoders.

This is a typical chunk-by-chunk compression pattern:

```ruby
compressor = Brotli::Compressor.new

compressed_chunk = compressor.process(input_chunk)
compressed_chunk << compressor.flush

# when the input stream is finished
compressed_tail = compressor.finish
```

And this is the corresponding incremental decompression pattern:

```ruby
decompressor = Brotli::Decompressor.new
output = +""

compressed_chunks.each do |input_chunk|
  output << decompressor.process(input_chunk)
end

unless decompressor.finished?
  raise Brotli::Error, "Unexpected end of compressed stream"
end
```

For fully chunked or frame-based transports, call `#process` once per received
compressed chunk and append the returned output. `#finished?` tells you whether
the full Brotli stream has been decoded, and `#can_accept_more_data` indicates
whether the decompressor is ready for more input or still has buffered output to
drain first.

These low-level classes are useful when you need to plug Brotli into an
existing incremental pipeline without wrapping the stream in an IO-like object.

### `output_buffer_limit`

`Brotli::Decompressor#process` also accepts `output_buffer_limit:`:

```ruby
decompressor = Brotli::Decompressor.new
output = +""

compressed_chunks.each do |chunk|
  output << decompressor.process(chunk, output_buffer_limit: 16 * 1024)

  until decompressor.can_accept_more_data || decompressor.finished?
    output << decompressor.process("", output_buffer_limit: 16 * 1024)
  end
end

unless decompressor.finished?
  raise Brotli::Error, "Unexpected end of compressed stream"
end
```

`output_buffer_limit:` caps how many decompressed bytes are returned from a
single `#process` call. When the limit is reached, the decompressor may still
have buffered state to drain. In that case `#can_accept_more_data` returns
`false`, and you should keep calling `#process("")` until it becomes `true`
again or the stream is finished.

Use `output_buffer_limit:` when:

- you want to bound memory usage or work per iteration
- you are feeding decompressed bytes into a downstream consumer with backpressure
- you are integrating Brotli into an event loop, framed protocol, or chunked transport
- you are reading small slices from a large compressed payload and do not want a single call to return a very large output buffer

You usually do not need `output_buffer_limit:` when:

- you are using `Brotli.inflate` for one-shot decompression
- you are using `Brotli::Reader`, which already handles incremental buffering for IO-style reads
- you are happy for each `#process` call to return all currently available output

See test/brotli_test.rb for more examples.

## Development

After checking out the repo, run `bin/setup` to install bundle and Brotli C library dependencies.

Run `rake build` to build the Brotli extension for Ruby. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/miyucy/brotli.
