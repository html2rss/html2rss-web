# frozen_string_literal: true

require 'html2rss'
require 'html2rss/configs'

##
# Provides methods to work with html2rss and html2rss-configs without
# knowing much of their interface and details.
class Html2rssFacade
  private_class_method :new

  attr_reader :feed_config, :typecast_params

  ##
  # @param feed_config [Hash<Symbol, Object>]
  # @param typecast_params
  def initialize(feed_config, typecast_params)
    @feed_config = feed_config
    @typecast_params = typecast_params
  end

  ##
  # @param name [String] the name of a html2rss-configs provided config.
  # @param typecast_params
  # @return [String] the serializied RSS feed
  def self.from_config_name(name, typecast_params)
    feed_config = Html2rss::Configs.find_by_name(name)

    new(feed_config, typecast_params).feed
  end

  ##
  # @param name [String] the name of a feed in the file `config/feeds.yml`
  # @param typecast_params
  # @return [String] the serializied RSS feed
  def self.from_local_config(name, typecast_params)
    feed_config = LocalConfig.find name

    new(feed_config, typecast_params).feed
  end

  private

  ##
  # @return [String]
  def feed
    config = feed_config_to_config(feed_config, typecast_params)

    yield config if block_given?

    Html2rss.feed(config).to_s
  end

  ##
  # @return [Html2rss::Config]
  # @raise [Roda::RodaPlugins::TypecastParams::Error]
  def feed_config_to_config(feed_config, typecast_params, global_config: LocalConfig.global)
    dynamic_params = Html2rss::Config.required_params_for_feed_config(feed_config)
                                     .map { |name| [name, typecast_params.str!(name)] }
                                     .to_h

    Html2rss::Config.new(feed_config, global_config, dynamic_params)
  end
end
