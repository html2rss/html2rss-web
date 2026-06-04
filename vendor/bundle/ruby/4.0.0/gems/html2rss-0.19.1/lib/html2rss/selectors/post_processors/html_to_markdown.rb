# frozen_string_literal: true

require 'reverse_markdown'

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # Returns HTML code as Markdown formatted String.
      # Before converting to markdown, the HTML is sanitized with SanitizeHtml.
      # Imagine this HTML structure:
      #
      #     <section>
      #       Lorem <b>ipsum</b> dolor...
      #       <iframe src="https://evil.corp/miner"></iframe>
      #       <script>alert();</script>
      #     </section>
      #
      # YAML usage example:
      #
      #    selectors:
      #      description:
      #        selector: section
      #        extractor: html
      #        post_process:
      #          name: html_to_markdown
      #
      # Would return:
      #    'Lorem **ipsum** dolor'
      class HtmlToMarkdown < Base
        # @param value [String] extracted selector value
        # @param context [Selectors::Context] post-processor context
        # @return [void]
        def self.validate_args!(value, context)
          assert_type value, String, :value, context:
        end

        ##
        # @return [String] formatted in Markdown
        def get
          sanitized_value = SanitizeHtml.new(value, context).get

          ReverseMarkdown.convert(sanitized_value)
        end
      end
    end
  end
end
