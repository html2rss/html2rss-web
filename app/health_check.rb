# frozen_string_literal: true

require 'parallel'
require_relative 'local_config'
require_relative 'auth'

module Html2rss
  module Web
    ##
    # Checks if the local configs are generatable.
    module HealthCheck
      module_function

      ##
      # Find health-check account by username
      # @return [Hash, nil] account data if found
      def find_health_check_account
        Auth.accounts.find { |account| account[:username] == 'health-check' }
      end

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
    end
  end
end
