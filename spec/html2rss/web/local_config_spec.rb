# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/config/local_config'

RSpec.describe Html2rss::Web::LocalConfig do
  def titles_for(*names)
    names.map { |name| described_class.find(name)[:title] }
  end

  before do
    described_class.reload!
  end

  describe '.find' do
    it 'strips feed extensions before lookup' do
      allow(described_class).to receive(:yaml).and_return(
        { feeds: { example: { title: 'Example' } } }
      )

      expect(titles_for('example.json', 'example.rss', 'example.xml')).to eq(%w[Example Example Example])
    end

    it 'falls back to embedded configs when the feed is not in local yaml' do
      stub_const('Html2rss::Configs', Module.new do
        def self.find_by_name(_name); end
      end)
      stub_const('Html2rss::Configs::ConfigNotFound', Class.new(StandardError))
      allow(Html2rss::Configs)
        .to receive(:find_by_name)
        .with('support.apple.com/en_gb_ht201222')
        .and_return({ channel: { title: 'Apple security releases' } })
      allow(described_class).to receive(:snapshot)
        .and_return(Html2rss::Web::ConfigSnapshot::Snapshot.new(global: {}, feeds: {}, accounts: []))

      config = described_class.find('support.apple.com/en_gb_ht201222.rss')

      expect(config).to include(channel: { title: 'Apple security releases' })
    end

    it 'returns not found for malformed embedded config paths instead of depending on gem error messages' do
      stub_const('Html2rss::Configs', Module.new do
        def self.find_by_name(_name); end
      end)
      stub_const('Html2rss::Configs::ConfigNotFound', Class.new(StandardError))
      allow(Html2rss::Configs).to receive(:find_by_name)
      allow(described_class).to receive(:snapshot)
        .and_return(Html2rss::Web::ConfigSnapshot::Snapshot.new(global: {}, feeds: {}, accounts: []))

      expect { described_class.find('/broken-name.rss') }
        .to raise_error(described_class::NotFound, "Did not find local feed config at 'broken-name'")
      expect(Html2rss::Configs).not_to have_received(:find_by_name)
    end
  end

  describe '.snapshot' do
    let(:yaml_fixture) do
      {
        auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] },
        feeds: {}
      }
    end

    it 'builds typed account models from configuration' do
      allow(described_class).to receive(:yaml).and_return(yaml_fixture)
      described_class.reload!

      expect(described_class.snapshot.accounts.first.username).to eq('alice')
    end
  end
end
