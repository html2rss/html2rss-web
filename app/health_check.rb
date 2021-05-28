require_relative 'local_config.rb'

module HealthCheck
  module_function

  def check
    broken_feeds = errors

    if broken_feeds.any?
      broken_feeds.join("\n")
    else
      'success'
    end
  end

  def errors
    [].tap do |errors|
      LocalConfig.feeds.each_key do |feed_name|
        Html2rss.feed_from_yaml_config(LocalConfig::CONFIG_FILE, feed_name).to_s
      rescue e
        errors << "#{feed_name}: #{e.message}"
      end
    end
  end
end
