require 'sinatra'
require 'yaml'
require 'html2rss'

class App < Sinatra::Base
  CONFIG_FILE = 'config/feeds.yml'.freeze
  FEED_NAMES = YAML.load(File.open(CONFIG_FILE))['feeds'].keys.freeze

  FEED_NAMES.each do |feed_name|
    get "/#{feed_name}.rss" do
      content_type 'text/xml'
      Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name).to_s
    end
  end

  get '/health_check.txt' do
    content_type 'text/plain'

    errors = []

    FEED_NAMES.each do |feed_name|
      begin
        Html2rss.feed_from_yaml_config(CONFIG_FILE, feed_name).to_s
      rescue => error
        errors << "#{feed_name}: #{error.message}"
      end
    end

    errors.count > 0 ? errors.join("\n") : 'success'
  end
end
