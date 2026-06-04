# frozen_string_literal: true

require 'regexp_parser'

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # Imagine this HTML:
      #    <h1>Foo bar and boo<h1>
      #
      # YAML usage example:
      #    selectors:
      #      title:
      #        selector: h1
      #        post_process:
      #          name: gsub
      #          pattern: boo
      #          replacement: baz
      #
      # Would return:
      #    'Foo bar and baz'
      #
      # `pattern` can be a Regexp or a String. If it is a String, it will remove
      # one pair of surrounding slashes ('/') to keep backwards compatibility
      # and then parse it to build a Regexp.
      #
      # `replacement` can be a String or a Hash.
      #
      # See the doc on [String#gsub](https://ruby-doc.org/core/String.html#method-i-gsub) for more info.
      class Gsub < Base
        # @param value [String] extracted selector value
        # @param context [Selectors::Context] post-processor context
        # @return [void]
        def self.validate_args!(value, context)
          assert_type value, String, :value, context:
          expect_options(%i[replacement pattern], context)
          assert_type context.dig(:options, :replacement), [String, Hash], :replacement, context:
        end

        ##
        # @param value [String]
        # @param context [Selectors::Context]
        def initialize(value, context)
          super

          options = context[:options]

          @replacement = options[:replacement]
          @pattern = options[:pattern]
        end

        ##
        # @return [String]
        def get
          value.to_s.gsub(pattern, replacement)
        end

        private

        attr_accessor :replacement

        ##
        # @return [Regexp]
        def pattern
          @pattern.is_a?(String) ? parse_regexp_string(@pattern) : @pattern
        end

        ##
        # Parses the given String and builds a Regexp out of it.
        #
        # It will remove one pair of surrounding slashes ('/') from the String
        # to maintain backwards compatibility before building the Regexp.
        #
        # @param string [String]
        # @return [Regexp]
        def parse_regexp_string(string)
          raise ArgumentError, 'must be a string!' unless string.is_a?(String)

          # Only remove surrounding slashes if the string has at least 3 characters
          # to avoid issues with single character strings like "/"
          string = string[1..-2] if string.length >= 3 && string.start_with?('/') && string.end_with?('/')
          Regexp::Parser.parse(string, options: ::Regexp::EXTENDED | ::Regexp::IGNORECASE).to_re
        end
      end
    end
  end
end
