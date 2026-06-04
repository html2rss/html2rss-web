# frozen_string_literal: true

require 'zlib'
require 'stringio'

# Middleware to automatically decompress response bodies. If the
# "Accept-Encoding" header wasn't set in the request, this sets it to
# "gzip,deflate" and appropriately handles the compressed response from the
# server. This resembles what Ruby 1.9+ does internally in Net::HTTP#get.
# Based on https://github.com/lostisland/faraday_middleware/blob/main/lib/faraday_middleware/gzip.rb
module Faraday
  # Main module
  module Gzip
    # Faraday middleware for decompression
    class Middleware < Faraday::Middleware
      ACCEPT_ENCODING  = 'Accept-Encoding'
      CONTENT_ENCODING = 'Content-Encoding'
      CONTENT_LENGTH   = 'Content-Length'
      IDENTITY         = 'identity'

      # System method required by Faraday
      def self.optional_dependency(lib = nil)
        lib ? require(lib) : yield
        true
      rescue LoadError, NameError
        false
      end

      BROTLI_SUPPORTED = optional_dependency 'brotli'

      # Returns supported encodings, adds brotli if the corresponding
      # dependency is present
      def self.supported_encodings
        encodings = %w[gzip deflate]
        encodings << 'br' if BROTLI_SUPPORTED
        encodings
      end

      SUPPORTED_ENCODINGS = supported_encodings.join(',').freeze

      # Main method to process the response
      def call(env)
        env[:request_headers][ACCEPT_ENCODING] ||= SUPPORTED_ENCODINGS

        @app.call(env).on_complete do |response_env|
          reset_body(response_env, find_processor(response_env))
        end
      end

      # Finds a proper processor
      def find_processor(response_env)
        body = response_env[:body]

        encodings = parse_content_encoding(
          response_env[:response_headers][CONTENT_ENCODING]
        )
        return nil if encodings.empty? || encodings.include?(IDENTITY)

        # If body is nil/empty, we still want to normalize headers:
        # Content-Encoding is meaningless without an encoded body.
        return ->(b) { b } if body_nil_or_empty?(body)

        chain = processor_chain(encodings)
        return nil if chain.empty?

        ->(b) { chain.reduce(b) { |acc, fn| fn.call(acc) } }
      end

      # Calls the proper processor to decompress body
      def reset_body(env, processor)
        return if processor.nil?

        body    = env[:body]
        headers = env[:response_headers]

        # Don't touch streaming / IO-like bodies.
        return unless body.is_a?(String) || body_nil_or_empty?(body)

        if body.is_a?(String)
          env[:body] = processor.call(body)
          headers[CONTENT_LENGTH] = env[:body].bytesize
        end

        # Normalize encoding header even for nil/empty body.
        headers.delete(CONTENT_ENCODING)
      end

      # Process gzip
      def uncompress_gzip(body)
        io = StringIO.new(body)
        gzip_reader = Zlib::GzipReader.new(io, encoding: 'ASCII-8BIT')
        begin
          gzip_reader.read
        ensure
          gzip_reader.close
        end
      end

      # Process deflate
      def inflate(body)
        # Inflate as a DEFLATE (RFC 1950+RFC 1951) stream
        Zlib::Inflate.inflate(body)
      rescue Zlib::DataError
        # Fall back to inflating as a "raw" deflate stream which
        # Microsoft servers return
        inflate = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        begin
          inflate.inflate(body)
        ensure
          inflate.close
        end
      end

      # Process brotli
      def brotli_inflate(body)
        Brotli.inflate(body)
      end

      private

      def body_nil_or_empty?(body)
        return true if body.nil?
        return body.empty? if body.respond_to?(:empty?)
        # rubocop:disable Style/ZeroLengthPredicate
        return body.size.zero? if body.respond_to?(:size)
        # rubocop:enable Style/ZeroLengthPredicate

        false
      end

      def parse_content_encoding(value)
        return [] if value.nil?

        value.to_s
             .split(',')
             .map { |v| v.strip.downcase }
             .reject(&:empty?)
      end

      # Decode in reverse order of application:
      # "gzip, br"  => br -> gzip
      def processor_chain(encodings)
        encodings.reverse.filter_map { |enc| processors[enc] }
      end

      def processors
        @processors ||= {
          'gzip' => ->(body) { uncompress_gzip(body) },
          'deflate' => ->(body) { inflate(body) },
          'br' => (BROTLI_SUPPORTED ? ->(body) { brotli_inflate(body) } : nil)
        }
      end
    end
  end
end
