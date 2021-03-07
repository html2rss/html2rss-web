# frozen_string_literal: true

require 'sinatra'
require 'html2rss'
require 'html2rss/configs'
require 'yaml'

##
#
class App < Sinatra::Base
  CONFIG_FILE = 'config/feeds.yml'
  CONFIG_YAML = YAML.safe_load(File.open(CONFIG_FILE)).freeze

  get '/health_check.txt' do
    content_type 'text/plain'

    broken_feeds = errors

    if broken_feeds.any?
      status 500
      broken_feeds.join("\n")
    else
      status 200
      'success'
    end
  end

  get '/*.rss' do
    feed_name = params[:splat].first

    feed_config = begin
      yaml_feeds[feed_name] || Html2rss::Configs.find_by_name(feed_name)
    rescue StandardError
      nil
    end

    feed_config ? respond_with_feed(feed_config, params) : status(404)
  end

  private

  def respond_with_feed(feed_config, params)
    config = Html2rss::Config.new(feed_config, global_config, params)
    feed = Html2rss.feed(config)

    content_type 'text/xml'
    expires(config.ttl * 60, :public, :must_revalidate)
    items?(feed) ? feed.to_s : status(500)
  end

  def items?(feed)
    feed.items.count.positive?
  end

  def global_config
    @global_config ||= CONFIG_YAML.reject { |key| key == 'feeds' }
  end

  def yaml_feeds
    CONFIG_YAML.fetch('feeds') || {}
  end

  def yaml_feed_names
    yaml_feeds.keys
  end

  def errors
    [].tap do |errors|
      yaml_feed_names.each do |feed_name|
        Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name).to_s
      rescue e
        errors << "#{feed_name}: #{e.message}"
      end
    end
  end
end
