require 'sinatra'
require 'yaml'
require 'html2rss'
require 'json'

class App < Sinatra::Base
  CONFIG_FILE = 'config/feeds.yml'.freeze
  FEED_NAMES = YAML.load(File.open(CONFIG_FILE))['feeds'].keys.freeze

  FEED_NAMES.each do |feed_name|
    get "/#{feed_name}.rss" do
      content_type 'text/xml'
      Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name).to_s
    end

    get "/#{feed_name}.json" do
      content_type 'application/json'
      json_from_feed Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name)
    end
  end

  get '/health_check.txt' do
    content_type 'text/plain'

    errors = []

    FEED_NAMES.each do |feed_name|
      begin
        Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name).to_s
      rescue StandardError => error
        errors << "#{feed_name}: #{error.message}"
      end
    end

    errors.count > 0 ? errors.join("\n") : 'success'
  private

  def json_from_feed(feed)
    JSON.generate(
      version: 'https://jsonfeed.org/version/1',
      title: feed.channel.title,
      items: json_items_from_feed_items(feed.items)
    )
  end

  def json_items_from_feed_items(items)
    items.map { |item|
      {
        id: item.guid.content,
        url: item.link,
        title: item.title,
        content_html: item.description,
        author: { name: item.author }
      }
    }
  end
end
