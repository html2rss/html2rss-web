# frozen_string_literal: true

require 'fileutils'
require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::Index do
  describe '#config_for' do
    it 'returns registry configs by feed id' do
      config = described_class.current.config_for('support.apple.com/en_gb_ht201222')

      expect(config).to include(channel: hash_including(title: 'Apple Support — Security releases'))
    end

    it 'returns nil for unknown ids' do
      expect(described_class.current.config_for('missing.example/feed')).to be_nil
    end

    it 'still resolves catalog-disabled registry feeds by id' do
      config = described_class.current.config_for('secret.example/private')

      expect(config).to include(channel: hash_including(url: 'https://secret.example/private'))
    end
  end

  describe '#catalog_rows' do
    it 'includes registry rows with source and registry fields' do
      rows = described_class.current.catalog_rows
      phys = rows.find { |row| row.fetch(:id) == 'phys.org/weekly' }

      expect(phys).to include(
        source: 'registry',
        registry: 'official',
        path: '/phys.org/weekly.rss'
      )
    end

    it 'omits catalog-disabled registries from the catalog API rows' do
      rows = described_class.current.catalog_rows

      expect(rows.map { |row| row.fetch(:id) }).not_to include('secret.example/private')
    end

    it 'prefers the first registry in precedence for duplicate feed ids' do
      rows = described_class.current.catalog_rows
      apple = rows.find { |row| row.fetch(:id) == 'support.apple.com/en_gb_ht201222' }

      expect(apple.fetch(:registry)).to eq('official')
    end
  end

  describe '#status' do
    it 'reports loaded registry metadata' do
      status = described_class.current.status
      official = status.find { |entry| entry.id == 'official' }

      expect(official).to have_attributes(
        version: 'test-fixture',
        sync_mode: :path
      )
    end
  end

  describe 'allowed_channel_domains' do
    let(:config_path) { File.join(Dir.pwd, 'tmp', 'domain-allowlist-registries.yml') }

    before do
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, <<~YAML)
        precedence:
          - official
        registries:
          official:
            path: spec/fixtures/registries/official
            catalog: true
            allowed_channel_domains:
              - blocked.example
      YAML
      ENV['REGISTRIES_CONFIG'] = config_path
      described_class.reload!
    end

    after do
      FileUtils.rm_f(config_path)
    end

    it 'rejects bundles with channel URLs outside the allowlist' do
      expect { described_class.current.config_for('phys.org/weekly') }
        .to raise_error(Html2rss::Web::Registry::Errors::LoadError, /phys.org/)
    end
  end
end
