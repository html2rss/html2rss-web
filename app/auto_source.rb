# frozen_string_literal: true

require 'uri'
require_relative 'auth'
require_relative 'xml_builder'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Auto source functionality for generating RSS feeds from any website
    module AutoSource
      module_function

      def enabled?
        # Enable by default in development, require explicit setting in production
        if development?
          ENV.fetch('AUTO_SOURCE_ENABLED', nil) != 'false'
        else
          ENV.fetch('AUTO_SOURCE_ENABLED', nil) == 'true'
        end
      end

      def authenticate_with_token(request)
        Auth.authenticate(request)
      end

      def allowed_origin?(request)
        origin = request.env['HTTP_HOST'] || request.env['HTTP_X_FORWARDED_HOST']
        origins = allowed_origins
        origins.empty? || origins.include?(origin)
      end

      def allowed_origins
        if development?
          default_origins = 'localhost:3000,localhost:3001,127.0.0.1:3000,127.0.0.1:3001'
          origins = ENV.fetch('AUTO_SOURCE_ALLOWED_ORIGINS', default_origins)
        else
          origins = ENV.fetch('AUTO_SOURCE_ALLOWED_ORIGINS', '')
        end
        origins.split(',').map(&:strip)
      end

      def url_allowed_for_token?(token_data, url)
        # Get full account data from config
        account = Auth.get_account_by_username(token_data[:username])
        return false unless account

        Auth.url_allowed?(account, url)
      end

      def create_stable_feed(name, url, token_data, strategy = 'ssrf_filter')
        return nil unless url_allowed_for_token?(token_data, url)

        feed_id = Auth.generate_feed_id(token_data[:username], url, token_data[:token])
        feed_token = Auth.generate_feed_token(token_data[:username], url)
        return nil unless feed_token

        build_feed_data(name, url, token_data, strategy, feed_id, feed_token)
      end

      def generate_feed_from_stable_id(feed_id, token_data)
        return nil unless token_data

        # Reconstruct feed data from token and feed_id
        # This is stateless - we don't store anything permanently
        {
          id: feed_id,
          url: nil, # Will be provided in request
          username: token_data[:username],
          strategy: 'ssrf_filter'
        }
      end

      private

      def build_feed_data(name, url, token_data, strategy, feed_id, feed_token)
        public_url = "/feeds/#{feed_id}?token=#{feed_token}&url=#{URI.encode_www_form_component(url)}"

        {
          id: feed_id,
          name: name,
          url: url,
          username: token_data[:username],
          strategy: strategy,
          public_url: public_url
        }
      end

      def generate_feed_content(url, strategy = 'ssrf_filter')
        feed_content = call_strategy(url, strategy)

        # Check if feed is empty and provide better error handling
        if feed_content.respond_to?(:to_s)
          feed_xml = feed_content.to_s
          if feed_xml.include?('<item>') == false
            # Feed has no items - this might be a content extraction issue
            return create_empty_feed_warning(url, strategy)
          end
        end

        feed_content
      end

      def create_empty_feed_warning(url, strategy)
        site_title = extract_site_title(url)
        XmlBuilder.build_empty_feed_warning(
          url: url,
          strategy: strategy,
          site_title: site_title
        )
      end

      def call_strategy(url, strategy)
        global_config = LocalConfig.global

        config = {
          stylesheets: global_config[:stylesheets],
          headers: global_config[:headers],
          strategy: strategy.to_sym,
          channel: {
            url: url
          },
          auto_source: {
            # Auto source configuration for automatic content detection
            # This allows Html2rss to automatically detect content on the page
          }
        }

        Html2rss.feed(config)
      end

      def extract_site_title(url)
        Html2rss::Url.for_channel(url).channel_titleized
      rescue StandardError
        nil
      end

      def error_feed(message)
        XmlBuilder.build_error_feed(message: message)
      end

      def access_denied_feed(url)
        XmlBuilder.build_access_denied_feed(url)
      end

      def development?
        ENV.fetch('RACK_ENV', nil) == 'development'
      end
    end
  end
end
