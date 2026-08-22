# frozen_string_literal: true

require 'openssl'
require 'fileutils'
require 'zlib'
require 'stringio'
require 'rubygems/package'

module RegistrySyncTestHelpers
  HTML2RSS_FIXTURES = File.expand_path('../../../html2rss/spec/fixtures/registry', __dir__)
  TEST_PUBLIC_KEY = File.read(File.join(HTML2RSS_FIXTURES, 'test-key.pub'))
  TEST_PRIVATE_KEY = File.read(File.join(HTML2RSS_FIXTURES, 'test-key.pem'))
  SYNC_FIXTURES_ROOT = File.expand_path('../fixtures/registries/sync', __dir__)
  SYNC_REGISTRIES_CONFIG = File.join(SYNC_FIXTURES_ROOT, 'registries.yml')
  SYNC_DATA_ROOT = File.join(Dir.pwd, 'tmp', 'sync-registry-data')

  module_function

  def configure_sync_registry!
    ENV['REGISTRIES_CONFIG'] = SYNC_REGISTRIES_CONFIG
    ENV['REGISTRY_DATA_ROOT'] = SYNC_DATA_ROOT
    ENV['REGISTRY_SYNC_ALLOWED_HOSTS'] = 'registry.test.example'
    FileUtils.rm_rf(SYNC_DATA_ROOT)
    Html2rss::Web::Registry::Index.reload!
  end

  def build_signed_tarball # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    bundle_dir = Dir.mktmpdir('signed-registry-bundle')
    FileUtils.cp_r(File.join(SYNC_FIXTURES_ROOT, 'bundle', '.'), bundle_dir)
    manifest = Html2rss::Registry::Manifest.parse(
      File.read(File.join(bundle_dir, Html2rss::Registry::Manifest::MANIFEST_FILE))
    )
    private_key = OpenSSL::PKey.read(TEST_PRIVATE_KEY)
    signature = private_key.sign(nil, manifest.canonical_bytes)
    File.write(
      File.join(bundle_dir, Html2rss::Registry::Manifest::SIGNATURE_FILE),
      [signature].pack('m0')
    )

    tar_io = StringIO.new
    Gem::Package::TarWriter.new(tar_io) do |tar|
      Dir.glob(File.join(bundle_dir, '**', '*'), File::FNM_DOTMATCH).sort.each do |path|
        next if File.directory?(path)

        relative = path.delete_prefix("#{bundle_dir}/")
        tar.add_file(relative, 0o644) { |io| io.write(File.binread(path)) }
      end
    end

    gz_io = StringIO.new
    Zlib::GzipWriter.wrap(gz_io) { |gz| gz.write(tar_io.string) }
    gz_io.string
  ensure
    FileUtils.rm_rf(bundle_dir)
  end
end

RSpec.configure do |config|
  config.before do |example|
    next unless example.metadata[:registry_sync]

    RegistrySyncTestHelpers.configure_sync_registry!
  end
end
