# frozen_string_literal: true

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # Returns a formatted String according to the string pattern.
      # It uses [Kernel#format](https://ruby-doc.org/core/Kernel.html#method-i-format)
      #
      # It supports the format pattern `%<key>s` and `%{key}`, where `key` is the key of the selector.
      # If `%{self}` is used, the selectors extracted value will be used.
      #
      # Imagine this HTML:
      #
      #    <li>
      #      <h1>Product</h1>
      #      <span class="price">23,42€</span>
      #    </li>
      #
      #
      # YAML usage example:
      #
      #    selectors:
      #      items:
      #        selector: 'li'
      #      price:
      #        selector: '.price'
      #      title:
      #        selector: h1
      #        post_process:
      #          name: template
      #          string: '%{self} (%{price})'
      #
      # Would return:
      #    'Product (23,42€)'
      class Template < Base
        # @param value [String] extracted selector value
        # @param context [Selectors::Context] post-processor context
        # @return [void]
        def self.validate_args!(value, context)
          assert_type value, String, :value, context:

          string = context[:options]&.dig(:string).to_s
          raise InvalidType, 'The `string` template is absent.' if string.empty?
        end

        ##
        # @param value [String]
        # @param context [Selectors::Context]
        def initialize(value, context)
          super

          @options = context[:options] || {}
          @scraper = context[:scraper]
          @item = context[:item]
          @string = @options[:string].to_s
        end

        ##
        # @return [String]
        def get
          Html2rss::Config::DynamicParams.call(@string, {}, getter: method(:item_value), replace_missing_with: '')
        end

        private

        # @param key [String, Symbol]
        # @return [String]
        def item_value(key)
          key = key.to_sym
          key == :self ? value : @scraper.select(key, @item)
        end
      end
    end
  end
end
