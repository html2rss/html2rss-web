# frozen_string_literal: true

require 'parallel'
require_relative 'local_config'
require 'securerandom'
require 'singleton'

module Html2rss
  module Web
    ##
    # Checks if the local configs are generatable.
    module HealthCheck
      ##
      # Contains logic to obtain username and password to be used with HealthCheck endpoint.
      class Auth
        include Singleton

        def self.username = instance.username
        def self.password = instance.password

        def username
          @username ||= fetch_credential('HEALTH_CHECK_USERNAME')
        end

        def password
          @password ||= fetch_credential('HEALTH_CHECK_PASSWORD')
        end

        private

        def fetch_credential(env_var)
          ENV.delete(env_var) do
            SecureRandom.base64(32).tap do |string|
              warn "ENV var. #{env_var} missing! Using generated value instead: #{string}"
            end
          end
        end
      end

      module_function

      ##
      # @return [String] "success" when all checks passed.
      def run
        broken_feeds = errors
        broken_feeds.any? ? broken_feeds.join("\n") : 'success'
      end

      ##
      # @return [Array<String>]
      def errors
        [].tap do |errors|
          Parallel.each(LocalConfig.feed_names) do |feed_name|
            Html2rss.feed_from_yaml_config(LocalConfig::CONFIG_FILE, feed_name.to_s)
          rescue StandardError => error
            errors << "[#{feed_name}] #{error.class}: #{error.message}"
          end
        end
      end

      def format_error(feed_name, error)
        "[#{feed_name}] #{error.class}: #{error.message}"
      end

      private_class_method :format_error
    end
  end
end
