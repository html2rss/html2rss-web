# frozen_string_literal: true

module Brotli
  class Reader
    DEFAULT_READ_SIZE = 8192

    def initialize(io, options = nil, **kwargs)
      raise ArgumentError, "io should not be nil" if io.nil?

      @io = io
      @decompressor = Decompressor.new(normalize_options(options, kwargs))
      @output_buffer = +""
      @closed = false
      @finished = false
    end

    def read(length = nil, outbuf = nil)
      ensure_open

      if length.nil?
        drain_stream
        return replace_outbuf(outbuf, take_output)
      end

      len = Integer(length)
      raise ArgumentError, "negative length #{len} given" if len.negative?
      return replace_outbuf(outbuf, +"") if len.zero?

      fill_buffer(len, output_limit: len)
      if @output_buffer.empty? && @finished
        replace_outbuf(outbuf, +"") if outbuf
        return nil
      end

      replace_outbuf(outbuf, take_output(len))
    end

    def readpartial(maxlen, outbuf = nil)
      ensure_open

      len = Integer(maxlen)
      raise ArgumentError, "max length must be positive" unless len.positive?

      until @finished || !@output_buffer.empty?
        fill_buffer(1, output_limit: len, stop_after_output: true)
      end

      if @output_buffer.empty?
        replace_outbuf(outbuf, +"") if outbuf
        raise EOFError, "end of file reached"
      end

      replace_outbuf(outbuf, take_output(len))
    end

    def eof?
      ensure_open

      return false unless @output_buffer.empty?

      fill_buffer(1, output_limit: 1, stop_after_output: true) unless @finished
      @output_buffer.empty? && @finished
    end

    def close
      return @io if @closed

      begin
        @io.close if @io.respond_to?(:close)
      ensure
        @closed = true
        @finished = true
        @decompressor = nil
        @output_buffer.clear
      end

      @io
    end

    def closed?
      @closed
    end

    private

    def ensure_open
      raise Error, "Reader is closed" if @closed
    end

    def replace_outbuf(outbuf, string)
      return string unless outbuf

      buffer = coerce_string(outbuf)
      buffer.replace(string)
      buffer
    end

    def take_output(length = @output_buffer.bytesize)
      return +"".b if length <= 0 || @output_buffer.empty?

      if length >= @output_buffer.bytesize
        output = @output_buffer
        @output_buffer = +""
        return output
      end

      @output_buffer.slice!(0, length)
    end

    def drain_stream
      fill_buffer(@output_buffer.bytesize + 1) until @finished
    end

    def fill_buffer(wanted, output_limit: nil, stop_after_output: false)
      while @output_buffer.bytesize < wanted && !@finished
        buffered = @output_buffer.bytesize
        chunk = next_chunk
        feed_chunk(chunk || +"", output_limit: remaining_output_limit(output_limit))
        break if stop_after_output && !@output_buffer.empty?

        next unless chunk.nil? || chunk.empty?
        next if @finished || @output_buffer.bytesize > buffered || !@decompressor.can_accept_more_data

        raise Error, "Unexpected end of compressed stream"
      end
    end

    def feed_chunk(chunk, output_limit: nil)
      output = if output_limit&.positive?
        @decompressor.process(chunk, output_buffer_limit: output_limit)
      else
        @decompressor.process(chunk)
      end

      @output_buffer << output unless output.empty?
      @finished = @decompressor.finished?
    end

    def next_chunk
      return +"".b unless @decompressor.can_accept_more_data

      @io.respond_to?(:readpartial) ? @io.readpartial(DEFAULT_READ_SIZE) : @io.read(DEFAULT_READ_SIZE)
    rescue EOFError
      nil
    end

    def remaining_output_limit(output_limit)
      return unless output_limit

      [output_limit - @output_buffer.bytesize, 0].max
    end

    def normalize_options(options, kwargs)
      return kwargs if options.nil?

      unless options.is_a?(Hash)
        raise TypeError, "no implicit conversion of #{options.class} into Hash"
      end

      kwargs.empty? ? options : options.merge(kwargs)
    end

    def coerce_string(value)
      String.try_convert(value) || raise(TypeError, "no implicit conversion of #{value.class} into String")
    end
  end
end
