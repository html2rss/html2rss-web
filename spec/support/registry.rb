# frozen_string_literal: true

module RegistryTestHelpers
  FIXTURES_ROOT = File.expand_path('../fixtures/registries', __dir__)
  DEFAULT_REGISTRIES_CONFIG = File.join(FIXTURES_ROOT, 'registries.yml')

  module_function

  def configure_registry_fixtures!
    ENV['REGISTRIES_CONFIG'] = DEFAULT_REGISTRIES_CONFIG
    ENV['REGISTRY_DATA_ROOT'] = File.join(Dir.pwd, 'tmp', 'test-registry-data')
  end

  def reset_registry!
    Html2rss::Web::Registry::Index.reload!
  end
end

RSpec.configure do |config|
  config.before do
    RegistryTestHelpers.configure_registry_fixtures!
    RegistryTestHelpers.reset_registry!
  end
end
