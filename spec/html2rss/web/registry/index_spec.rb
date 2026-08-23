# frozen_string_literal: true

require 'fileutils'
require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::Index do
  describe '#config_for' do
    it 'returns registry configs by feed id' do
      config = described_class.current.config_for('anthropic.com/news')

      expect(config).to include(channel: hash_including(title: 'Anthropic — News'))
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
      anthropic = rows.find { it.fetch(:id) == 'anthropic.com/news' }

      expect(anthropic).to include(
        source: 'registry',
        registry: 'official',
        path: '/anthropic.com/news.rss'
      )
    end

    it 'omits catalog-disabled registries from the catalog API rows' do
      rows = described_class.current.catalog_rows

      expect(rows.map { it.fetch(:id) }).not_to include('secret.example/private')
    end

    it 'prefers the first registry in precedence for duplicate feed ids' do
      rows = described_class.current.catalog_rows
      deepmind = rows.find { it.fetch(:id) == 'deepmind.google/blog' }

      expect(deepmind.fetch(:registry)).to eq('official')
    end

    it 'merges local feeds.yml rows after registry rows', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      allow(Html2rss::Web::LocalConfig).to receive(:feeds).and_return(
        'team/releases' => {
          directory: { title: 'Team Releases', summary: 'Internal release notes' },
          channel: { url: 'https://team.example/releases', title: 'Team Releases' }
        }
      )

      rows = described_class.current.catalog_rows
      local = rows.find { it.fetch(:id) == 'team/releases' }

      expect(local).to include(
        source: 'local',
        path: '/team/releases.rss',
        directory: hash_including(title: 'Team Releases'),
        channel: hash_including(url: 'https://team.example/releases')
      )
      expect(local).not_to have_key(:registry)
    end
  end

  describe '#status' do
    it 'reports loaded registry metadata' do
      status = described_class.current.status
      official = status.find { it.id == 'official' }

      expect(official).to have_attributes(
        version: 'test-fixture',
        mode: :path
      )
    end
  end

  describe 'allowed_channel_domains' do
    let(:config_path) { File.join(Dir.pwd, 'tmp', 'domain-allowlist-registries.yml') }

    after do
      FileUtils.rm_f(config_path)
    end

    it 'allows suffix-matching channel domains via config load' do # rubocop:disable RSpec/ExampleLength
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, <<~YAML)
        precedence:
          - official
        registries:
          official:
            path: spec/fixtures/registries/official
            catalog: true
            allowed_channel_domains:
              - anthropic.com
              - deepmind.google
      YAML
      ENV['REGISTRIES_CONFIG'] = config_path
      described_class.reload!

      expect(described_class.current.config_for('anthropic.com/news')).to include(
        channel: hash_including(url: 'https://www.anthropic.com/news')
      )
    end

    it 'rejects bundles with channel URLs outside the allowlist' do # rubocop:disable RSpec/ExampleLength
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

      expect { described_class.current.config_for('anthropic.com/news') }
        .to raise_error(Html2rss::Web::Registry::Errors::LoadError, /anthropic\.com/)
    end
  end
end
