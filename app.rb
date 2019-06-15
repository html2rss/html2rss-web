require 'sinatra'
require 'yaml'
require 'html2rss'
require 'json'

class App < Sinatra::Base
  CONFIG_FILE = 'config/feeds.yml'.freeze
  FEED_NAMES = YAML.safe_load(File.open(CONFIG_FILE))['feeds'].keys.freeze

  FEED_NAMES.each do |feed_name|
    get "/#{feed_name}.rss" do
      content_type 'text/xml'
      feed = Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name)

      items?(feed.items) ? feed.to_s : status(500)
    end

    get "/#{feed_name}.json" do
      content_type 'application/json'
      feed = Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name)

      items?(feed.items) ? json_from_feed(feed) : status(500)
    end
  end

  get '/' do
    erb :index, locals: { feed_names: FEED_NAMES }
  end

  get '/health_check.txt' do
    content_type 'text/plain'

    errors = []

    FEED_NAMES.each do |feed_name|
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

  private

  def items?(items)
    items.count.positive?
  end

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
