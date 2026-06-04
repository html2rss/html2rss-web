# frozen_string_literal: true

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # Returns a defined part of a String.
      #
      # Both parameters must be an Integer and they can be negative.
      # The +end+ parameter can be omitted, in that case it will not cut the
      # String at the end.
      #
      # A Regexp or a MatchString is not supported.
      #
      # See the [`String#[]`](https://ruby-doc.org/core/String.html#method-i-5B-5D)
      # documentation for more information.
      #
      # Imagine this HTML:
      #    <h1>Foo bar and baz<h1>
      #
      # YAML usage example:
      #    selectors:
      #      title:
      #        selector: h1
      #        post_process:
      #          name: substring
      #          start: 4
      #          end: 6
      #
      # Would return:
      #    'bar'
      class Substring < Base
        # @param value [String] extracted selector value
        # @param context [Selectors::Context] post-processor context
        # @return [void]
        def self.validate_args!(value, context)
          assert_type value, String, :value, context:

          options = context[:options]
          assert_type options[:start], Integer, :start, context:

          end_index = options[:end]
          assert_type(end_index, Integer, :end, context:) if end_index
        end

        ##
        # Extracts the substring from the original string based on the provided start and end indices.
        #
        # @return [String] The extracted substring.
        def get
          value[range]
        end

        ##
        # Determines the range for the substring extraction based on the provided start and end indices.
        #
        # @return [Range] The range object representing the start and end/Infinity (integers).
        def range
          return (start_index..) unless end_index?

          if start_index == end_index
            raise ArgumentError,
                  'The `start` value must be unequal to the `end` value.'
          end

          (start_index..end_index)
        end

        private

        def end_index?  = !context[:options][:end].to_s.empty?
        def end_index   = context[:options][:end].to_i
        def start_index = context[:options][:start].to_i
      end
    end
  end
end
