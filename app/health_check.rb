# frozen_string_literal: true

require_relative 'local_config'

module App
  ##
  # Checks if the local configs generate valid RSS feeds.
  module HealthCheck
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
          Html2rss.feed_from_yaml_config(LocalConfig::CONFIG_FILE, feed_name).to_s
        rescue e
          errors << "[#{feed_name}] #{e.class}: #{e.message}"
        end
      end
    end
  end
end
