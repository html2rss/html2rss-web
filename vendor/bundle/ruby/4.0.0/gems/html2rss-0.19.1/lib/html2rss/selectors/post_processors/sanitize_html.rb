# frozen_string_literal: true

require 'sanitize'
require_relative 'html_transformers/transform_urls_to_absolute_ones'
require_relative 'html_transformers/wrap_img_in_a'

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # Returns sanitized HTML code as String.
      #
      # It sanitizes by using the [sanitize gem](https://github.com/rgrove/sanitize) with
      # [Sanitize::Config::RELAXED](https://github.com/rgrove/sanitize#sanitizeconfigrelaxed).
      #
      # Furthermore, it adds:
      #
      # - `rel="nofollow noopener noreferrer"` to <a> tags
      # - `referrer-policy='no-referrer'` to <img> tags
      # - wraps all <img> tags, whose direct parent is not an <a>, into an <a>
      #   linking to the <img>'s `src`.
      #
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
      #        selector: '.section'
      #        extractor: html
      #        post_process:
      #          name: sanitize_html
      #
      # Would return:
      #    '<p>Lorem <b>ipsum</b> dolor ...</p>'
      class SanitizeHtml < Base
        # @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy
        TAG_ATTRIBUTES = {
          'a' => {
            'rel' => 'nofollow noopener noreferrer',
            'target' => '_blank'
          },

          'area' => {
            'rel' => 'nofollow noopener noreferrer',
            'target' => '_blank'
          },

          'img' => {
            'referrerpolicy' => 'no-referrer',
            'crossorigin' => 'anonymous',
            'loading' => 'lazy',
            'decoding' => 'async'
          },

          'iframe' => {
            'referrerpolicy' => 'no-referrer',
            'crossorigin' => 'anonymous',
            'loading' => 'lazy',
            'sandbox' => 'allow-same-origin',
            'src' => true,
            'width' => true,
            'height' => true
          },

          'video' => {
            'referrerpolicy' => 'no-referrer',
            'crossorigin' => 'anonymous',
            'preload' => 'none',
            'playsinline' => 'true',
            'controls' => 'true'
          },

          'audio' => {
            'referrerpolicy' => 'no-referrer',
            'crossorigin' => 'anonymous',
            'preload' => 'none'
          }
        }.freeze
        # @param value [String] extracted selector value
        # @param context [Selectors::Context] post-processor context
        # @return [void]
        def self.validate_args!(value, context)
          assert_type value, String, :value, context:
        end

        ##
        # Shorthand method to get the sanitized HTML.
        # @param html [String]
        # @param url [String, Html2rss::Url]
        # @return [String, nil]
        def self.get(html, url)
          return nil if String(html).empty?

          context = Selectors::Context.new(config: { channel: { url: } }, options: {})
          new(html, context).get
        end

        ##
        # @return [String, nil]
        def get
          sanitized_html = Sanitize.fragment(value, sanitize_config).to_s
          sanitized_html.gsub!(/\s+/, ' ')
          sanitized_html.strip!
          sanitized_html.empty? ? nil : sanitized_html
        end

        private

        def channel_url = context.dig(:config, :channel, :url)

        ##
        # @return [Sanitize::Config]
        def sanitize_config # rubocop:disable Metrics/MethodLength
          config = Sanitize::Config.merge(
            Sanitize::Config::RELAXED,
            attributes: { all: %w[dir lang alt title translate] },
            add_attributes: TAG_ATTRIBUTES,
            transformers: [
              method(:transform_urls_to_absolute_ones),
              method(:wrap_img_in_a)
            ]
          )
          config[:elements].push('audio', 'video', 'source')
          config
        end

        ##
        # Wrapper for transform_urls_to_absolute_ones to pass the channel_url.
        #
        # @param env [Hash]
        # @return [nil]
        def transform_urls_to_absolute_ones(env)
          HtmlTransformers::TransformUrlsToAbsoluteOnes.new(channel_url).call(**env)
        end

        ##
        # Wrapper for wrap_img_in_a.
        #
        # @param env [Hash]
        # @return [nil]
        def wrap_img_in_a(env)
          HtmlTransformers::WrapImgInA.new.call(**env)
        end
      end
    end
  end
end
