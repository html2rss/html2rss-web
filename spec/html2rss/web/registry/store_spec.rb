# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'digest'
require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::Store do
  let(:registry_id) { 'store-test' }
  let(:data_root) { File.join(Dir.pwd, 'tmp', 'store-spec-data') }

  let(:embedded_root) { File.join(Dir.pwd, 'tmp', 'store-spec-embedded') }

  before do
    ENV['REGISTRY_DATA_ROOT'] = data_root
    ENV['REGISTRY_EMBEDDED_ROOT'] = embedded_root
    FileUtils.rm_rf(data_root)
    FileUtils.rm_rf(embedded_root)
  end

  describe '.stage_bundle! and .promote_staged!' do
    it 'stages a verified bundle and promotes it to active', :aggregate_failures do
      source = build_bundle_dir('stage-source')
      active_before = build_bundle_dir('active-before')

      FileUtils.mkdir_p(File.dirname(described_class.registry_dir(registry_id)))
      FileUtils.cp_r(active_before, described_class.registry_dir(registry_id))

      described_class.stage_bundle!(registry_id, source)

      expect(described_class.staged_present?(registry_id)).to be(true)
      expect(described_class.staged_version(registry_id)).to eq('stage-source')
      expect(described_class.bundle_present?(registry_id)).to be(true)
      expect(read_manifest_version(described_class.registry_dir(registry_id))).to eq('active-before')

      described_class.promote_staged!(registry_id)

      expect(described_class.staged_present?(registry_id)).to be(false)
      expect(read_manifest_version(described_class.registry_dir(registry_id))).to eq('stage-source')
    end
  end

  describe '.bundle_present?' do
    it 'requires manifest.json instead of any non-empty directory' do
      path = described_class.registry_dir(registry_id)

      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(path)
      File.write(File.join(path, 'placeholder.txt'), 'content')

      expect(described_class.bundle_present?(registry_id)).to be(false)

      File.write(File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE), '{}')
      expect(described_class.bundle_present?(registry_id)).to be(true)
    end
  end

  describe '.active_dir' do
    let(:embedded_root) { File.join(Dir.pwd, 'tmp', 'store-spec-embedded') }

    before do
      ENV['REGISTRY_EMBEDDED_ROOT'] = embedded_root
      FileUtils.rm_rf(embedded_root)
    end

    it 'returns nil when neither synced nor embedded bundle exists' do
      expect(described_class.active_dir(registry_id)).to be_nil
    end

    it 'falls back to embedded bundle directory when synced bundle is absent' do
      embedded_dir = described_class.embedded_dir(registry_id)
      FileUtils.mkdir_p(embedded_dir)
      File.write(File.join(embedded_dir, Html2rss::Registry::Manifest::MANIFEST_FILE), '{}')

      expect(described_class.active_dir(registry_id)).to eq(embedded_dir)
    end

    it 'prefers synced runtime bundle over embedded bundle' do
      embedded_dir = described_class.embedded_dir(registry_id)
      FileUtils.mkdir_p(embedded_dir)
      File.write(File.join(embedded_dir, Html2rss::Registry::Manifest::MANIFEST_FILE), '{}')

      synced_dir = described_class.registry_dir(registry_id)
      FileUtils.mkdir_p(synced_dir)
      File.write(File.join(synced_dir, Html2rss::Registry::Manifest::MANIFEST_FILE), '{}')

      expect(described_class.active_dir(registry_id)).to eq(synced_dir)
    end
  end

  def build_bundle_dir(version) # rubocop:disable Metrics/MethodLength
    dir = Dir.mktmpdir("registry-store-#{version}")
    config_path = File.join(dir, 'configs', 'example.com', 'feed.yml')
    FileUtils.mkdir_p(File.dirname(config_path))
    File.write(config_path, "channel:\n  url: https://example.com/\n")
    digest = Digest::SHA256.file(config_path).hexdigest
    File.write(
      File.join(dir, Html2rss::Registry::Manifest::MANIFEST_FILE),
      {
        format: 'registry.v1',
        registry_id: 'store-test',
        version:,
        public_key_id: 'test',
        files: { 'configs/example.com/feed.yml' => digest }
      }.to_json
    )
    dir
  end

  def read_manifest_version(path)
    JSON.parse(File.read(File.join(path, Html2rss::Registry::Manifest::MANIFEST_FILE))).fetch('version')
  end
end
