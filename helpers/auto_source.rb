# frozen_string_literal: true

require 'addressable'
require 'base64'
require 'html2rss'

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
