# frozen_string_literal: true

module LocalConfig
  class NotFound < StandardError; end

  CONFIG_FILE = 'config/feeds.yml'

  module_function

  def find(name)
    feeds&.fetch(name, false) || raise(NotFound, "Did not find local feed config at '#{name}'")
  end

  def feeds
    yaml.fetch(:feeds, {})
  end

  def global_config
    yaml.reject { |key| key == :feeds }
  end

  def yaml
    # TODO: cache in production
    YAML.safe_load(File.open(CONFIG_FILE), symbolize_names: true).freeze
  end
end
