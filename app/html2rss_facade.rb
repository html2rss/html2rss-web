# frozen_string_literal: true

require 'html2rss'
require 'html2rss/configs'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Provides methods to work with html2rss and html2rss-configs without
    # knowing much of their interface.
    class Html2rssFacade
      private_class_method :new

      attr_reader :feed_config, :typecast_params

      ##
      # @param name [String] the name of a html2rss-configs provided config.
      # @param typecast_params [Object]
      # @return [String] the serialized RSS feed
      def self.from_config(name, typecast_params, &)
        feed_config = Html2rss::Configs.find_by_name(name)
        new(feed_config, typecast_params).feed(&)
      end

      ##
      # @param name [String] the name of a feed in the file `config/feeds.yml`
      # @param typecast_params [Object]
      # @return [String] the serialized RSS feed
      def self.from_local_config(name, typecast_params, &)
        feed_config = LocalConfig.find(name)
        new(feed_config, typecast_params).feed(&)
      end

      ##
      # @param feed_config [Hash<Symbol, Object>]
      # @param typecast_params [Object]
      # @param global_config [Hash<Symbol, Object>]
      # @return [Html2rss::Config]
      # @raise [Roda::RodaPlugins::TypecastParams::Error]
      def self.feed_config_to_config(feed_config, typecast_params, global_config: LocalConfig.global)
        dynamic_params = Html2rss::Config::Channel.required_params_for_config(feed_config[:channel])
                                                  .to_h { |name| [name, typecast_params.str!(name)] }
        Html2rss::Config.new(feed_config, global_config, dynamic_params)
      end

      ##
      # @param feed_config [Hash<Symbol, Object>]
      # @param typecast_params [Object]
      def initialize(feed_config, typecast_params)
        @feed_config = feed_config
        @typecast_params = typecast_params
      end

      ##
      # @return [String]
      def feed
        config = self.class.feed_config_to_config(feed_config, typecast_params)
        yield config if block_given?
        Html2rss.feed(config).to_s
      end
    end
  end
end
