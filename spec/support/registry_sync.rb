# frozen_string_literal: true

require 'fileutils'
require 'stringio'
require 'yaml'

module RegistrySyncTestHelpers
  FIXTURE_KEYS_ROOT = File.expand_path('../fixtures/registries/keys', __dir__)
  TEST_PUBLIC_KEY = File.read(File.join(FIXTURE_KEYS_ROOT, 'test-key.pub'))
  TEST_PRIVATE_KEY = File.read(File.join(FIXTURE_KEYS_ROOT, 'test-key.pem'))
  SYNC_FIXTURES_ROOT = File.expand_path('../fixtures/registries/sync', __dir__)
  SYNC_REGISTRIES_CONFIG = File.join(SYNC_FIXTURES_ROOT, 'registries.yml')
  SYNC_DATA_ROOT = File.join(Dir.pwd, 'tmp', 'sync-registry-data')

  module_function

  def configure_sync_registry!
    ENV['REGISTRIES_CONFIG'] = SYNC_REGISTRIES_CONFIG
    ENV['REGISTRY_DATA_ROOT'] = SYNC_DATA_ROOT
    ENV['REGISTRY_SYNC_ALLOWED_HOSTS'] = 'registry.test.example,release-assets.githubusercontent.com'
    FileUtils.rm_rf(SYNC_DATA_ROOT)
    Html2rss::Web::Registry::Index.reload!
  end

  def build_signed_tarball
    bundle_dir = Dir.mktmpdir('signed-registry-bundle')
    FileUtils.cp_r(File.join(SYNC_FIXTURES_ROOT, 'bundle', '.'), bundle_dir)
    manifest = Html2rss::Registry::Manifest.parse(
      File.read(File.join(bundle_dir, Html2rss::Registry::Manifest::MANIFEST_FILE))
    )
    Html2rss::Registry::TestSupport.sign!(manifest, key_pem: TEST_PRIVATE_KEY, bundle_dir:)

    pack_bundle_dir(bundle_dir)
  ensure
    FileUtils.rm_rf(bundle_dir)
  end

  def pack_bundle_dir(bundle_dir)
    dir = File.dirname(tarball_path = File.join(Dir.mktmpdir('registry-sync-tarball'), 'bundle.tar.gz'))
    env = { 'COPYFILE_DISABLE' => '1' }
    success = system(env, 'tar', '--format=ustar', '-czf', tarball_path, '-C', bundle_dir, '.', exception: false)
    raise "Failed to pack registry test bundle from #{bundle_dir}" unless success

    File.binread(tarball_path)
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def policy_registry_yaml(download_url:, auto_promote:, sync_extra: {}) # rubocop:disable Metrics/MethodLength
    sync = { 'url' => download_url }.merge(sync_extra.transform_keys(&:to_s))
    YAML.dump(
      {
        'precedence' => ['official'],
        'registries' => {
          'official' => {
            'sync' => sync,
            'auto_promote' => auto_promote,
            'catalog' => true,
            'public_key_id' => 'test-key',
            'public_key' => TEST_PUBLIC_KEY
          }
        }
      }
    )
  end
end

RSpec.configure do |config|
  config.before do |example|
    next unless example.metadata[:registry_sync]

    RegistrySyncTestHelpers.configure_sync_registry!
  end
end
