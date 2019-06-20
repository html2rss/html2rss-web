require 'sinatra'
require 'html2rss'
require 'html2rss/configs'
require 'yaml'

class App < Sinatra::Base
  CONFIG_FILE = 'config/feeds.yml'.freeze
  CONFIG_YAML = YAML.safe_load(File.open(CONFIG_FILE)).freeze
  FEED_NAMES = (CONFIG_YAML['feeds']&.keys || []).freeze

  FEED_NAMES.each do |feed_name|
    get "/#{feed_name}.rss" do
      content_type 'text/xml'
      feed = Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name)

      items?(feed.items) ? feed.to_s : status(500)
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

  get '/*.rss' do
    content_type 'text/xml'
    feed_name = params[:splat].first

    global_config = CONFIG_YAML.reject { |key| key == 'feeds' }
    global_config['feeds'] = {
      feed_name => Html2rss::Configs.find_by_name(feed_name)
    }

    config = Html2rss::Config.new(global_config, feed_name)
    feed = Html2rss.feed(config)

    items?(feed.items) ? feed.to_s : status(500)
  end

  private

  def items?(items)
    items.count.positive?
  end
end
