# frozen_string_literal: true

require_relative './local_config'
require 'singleton'

module App
  ##
  # Checks if the local configs are generatable.
  module HealthCheck
    ##
    # Contains logic to obtain username and password to be used with HealthCheck endpoint.
    class Auth
      def self.username
        @username ||= ENV.delete('HEALTH_CHECK_USERNAME') do
          SecureRandom.base64(32).tap do |string|
            puts "HEALTH_CHECK_USERNAME env var. missing! Please set it. Using generated value instead: #{string}"
          end
        end
      end

      def self.password
        @password ||= ENV.delete('HEALTH_CHECK_PASSWORD') do
          SecureRandom.base64(32).tap do |string|
            puts "HEALTH_CHECK_PASSWORD env var. missing! Please set it. Using generated value instead: #{string}"
          end
        end
      end
    end

    module_function

    ##
    # @return [String] "success" when all checks passed.
    def run
      broken_feeds = errors

      if broken_feeds.any?
        broken_feeds.join("\n")
      else
        'success'
      end
    end

    ##
    # @return [Array<String>]
    def errors
      [].tap do |errors|
        LocalConfig.feed_names.each do |feed_name|
          Html2rss.feed_from_yaml_config(LocalConfig::CONFIG_FILE, feed_name.to_s).to_s
        rescue StandardError => e
          errors << "[#{feed_name}] #{e.class}: #{e.message}"
        end
      end
    end
  end
end
