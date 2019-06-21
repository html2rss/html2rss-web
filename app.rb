require 'sinatra'
require 'html2rss'
require 'html2rss/configs'
require 'yaml'

class App < Sinatra::Base
  CONFIG_FILE = 'config/feeds.yml'.freeze
  CONFIG_YAML = YAML.safe_load(File.open(CONFIG_FILE)).freeze

  get '/health_check.txt' do
    content_type 'text/plain'

    errors = []

    yaml_feed_names.each do |feed_name|
      begin
        Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name).to_s
      rescue e
        errors << "#{feed_name}: #{e.message}"
      end
    end

    if errors.count.positive?
      status 500
      errors.join("\n")
    else
      status 200
      'success'
    end
  end

  get '/*.rss' do
    feed_name = params[:splat].first

    feed_config = yaml_feeds[feed_name] || Html2rss::Configs.find_by_name(feed_name)

    respond_with_feed(feed_config)
  end

  private

  def respond_with_feed(feed_config)
    config = Html2rss::Config.new(feed_config, global_config)
    feed = Html2rss.feed(config)

    content_type 'text/xml'
    expires config.ttl, :public, :must_revalidate
    items?(feed.items) ? feed.to_s : status(500)
  end

  def items?(items)
    items.count.positive?
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
end
