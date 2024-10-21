# frozen_string_literal: true

require 'addressable'
require 'base64'
require 'html2rss'
require 'ssrf_filter'

module Html2rss
  module Web
    ##
    # Helper methods for handling auto source feature.
    class AutoSource
      def self.enabled?        = ENV['AUTO_SOURCE_ENABLED'].to_s == 'true'
      def self.username        = ENV.fetch('AUTO_SOURCE_USERNAME')
      def self.password        = ENV.fetch('AUTO_SOURCE_PASSWORD')

      def self.allowed_origins = ENV.fetch('AUTO_SOURCE_ALLOWED_ORIGINS', '')
                                    .split(',')
                                    .map(&:strip)
                                    .reject(&:empty?)
                                    .to_set

      # @param encoded_url [String] Base64 encoded URL
      # @return [RSS::Rss]
      def self.build_auto_source_from_encoded_url(encoded_url)
        url = Addressable::URI.parse Base64.urlsafe_decode64(encoded_url)
        request = SsrfFilter.get(url)
        headers = request.to_hash.transform_values(&:first)

        auto_source = Html2rss::AutoSource.new(url, body: request.body, headers:)

        auto_source.channel.stylesheets << Html2rss::RssBuilder::Stylesheet.new(href: '/rss.xsl', type: 'text/xsl')

        auto_source.build
      end

      # @param rss [RSS::Rss]
      # @param default_in_minutes [Integer]
      # @return [Integer]
      def self.ttl_in_seconds(rss, default_in_minutes: 60)
        (rss&.channel&.ttl || default_in_minutes) * 60
      end

      # @param request [Roda::RodaRequest]
      # @param response [Roda::RodaResponse]
      # @param allowed_origins [Set<String>]
      def self.check_request_origin!(request, response, allowed_origins = AutoSource.allowed_origins)
        if allowed_origins.empty?
          response.write 'No allowed origins are configured. Please set AUTO_SOURCE_ALLOWED_ORIGINS.'
        else
          origin = Set[request.env['HTTP_HOST'], request.env['HTTP_X_FORWARDED_HOST']].delete(nil)
          return if allowed_origins.intersect?(origin)

          response.write 'Origin is not allowed.'
        end

        response.status = 403
        request.halt
      end
    end
  end
end
