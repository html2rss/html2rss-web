# frozen_string_literal: true

module Html2rss
  class Selectors
    ##
    # Provides a namespace for attribute post processors.
    module PostProcessors
      ##
      # Error raised when an unknown post processor name is requested.
      class UnknownPostProcessorName < Html2rss::Error; end

      ##
      # Error raised when a required option is missing.
      class MissingOption < Html2rss::Error; end

      ##
      # Error raised when an invalid type is provided.
      class InvalidType < Html2rss::Error; end

      ##
      # Maps the post processor name to the class implementing the post processor.
      #
      # The key is the name to use in the feed config.
      NAME_TO_CLASS = {
        gsub: Gsub,
        html_to_markdown: HtmlToMarkdown,
        markdown_to_html: MarkdownToHtml,
        parse_time: ParseTime,
        parse_uri: ParseUri,
        sanitize_html: SanitizeHtml,
        substring: Substring,
        template: Template
      }.freeze

      ##
      # Shorthand method to instantiate the post processor and call `#get` on it
      #
      # @param name [String, Symbol] post-processor name from selector config
      # @param value [Object] extracted selector value
      # @param context [Selectors::Context] post-processor context
      # @return [Object] transformed selector value
      def self.get(name, value, context)
        klass = NAME_TO_CLASS[name.to_sym] || raise(UnknownPostProcessorName, "Unknown name '#{name}'")
        klass.new(value, context).get
      end
    end
  end
end
