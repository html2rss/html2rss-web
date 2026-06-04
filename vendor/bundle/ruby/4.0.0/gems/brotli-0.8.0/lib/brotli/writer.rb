# frozen_string_literal: true

module Brotli
  class Writer
    def initialize(io, options = nil, **kwargs)
      raise ArgumentError, "io should not be nil" if io.nil?

      @io = io
      @compressor = Compressor.new(normalize_options(options, kwargs))
      @closed = false
    end

    def write(data)
      ensure_open

      data = coerce_string(data)
      write_output(@compressor.process(data))
      data.bytesize
    end

    def finish
      ensure_open

      write_output(@compressor.finish)
      @io
    end

    def flush
      ensure_open

      write_output(@compressor.flush)
      @io.flush if @io.respond_to?(:flush)
      self
    end

    def close
      return @io if @closed

      begin
        finish
      ensure
        begin
          @io.close if @io.respond_to?(:close)
        ensure
          @closed = true
          @compressor = nil
        end
      end

      @io
    end

    def closed?
      @closed
    end

    private

    def ensure_open
      raise Error, "Writer is closed" if @closed
    end

    def write_output(output)
      @io.write(output) unless output.empty?
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
