# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'
require 'tempfile'

require_relative '../../../app'

RSpec.describe Html2rss::Web::LocalConfig do
  let(:empty_snapshot) { Html2rss::Web::ConfigSnapshot::Snapshot.new(global: {}, feeds: {}, accounts: []) }

  def titles_for(*names)
    names.map { |name| described_class.find(name)[:title] }
  end

  def with_config_file(contents)
    Tempfile.create(['feeds', '.yml']) do |file|
      write_config(file, contents)
      stub_const("#{described_class}::CONFIG_FILE", file.path)
      yield file
    end
  end

  def write_config(file, contents)
    file.rewind
    file.truncate(0)
    file.write(contents)
    file.flush
  end

  def account_token(snapshot)
    snapshot.accounts.first.token
  end

  before do
    described_class.reload!
  end

  describe '.find' do
    it 'strips feed extensions before lookup' do
      allow(described_class).to receive(:snapshot).and_return(
        Html2rss::Web::ConfigSnapshot::Snapshot.new(
          global: {},
          feeds: {
            example: Html2rss::Web::ConfigSnapshot::FeedConfig.new(name: :example, raw: { title: 'Example' })
          },
          accounts: []
        )
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
      allow(described_class).to receive(:snapshot).and_return(empty_snapshot)

      config = described_class.find('support.apple.com/en_gb_ht201222.rss')

      expect(config).to include(channel: { title: 'Apple security releases' })
    end

    it 'returns not found for malformed embedded config paths instead of depending on gem error messages' do
      stub_const('Html2rss::Configs', Module.new do
        def self.find_by_name(_name); end
      end)
      stub_const('Html2rss::Configs::ConfigNotFound', Class.new(StandardError))
      allow(Html2rss::Configs).to receive(:find_by_name)
      allow(described_class).to receive(:snapshot).and_return(empty_snapshot)

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
      allow(described_class).to receive(:load_yaml).and_return(yaml_fixture)
      described_class.reload!

      expect(described_class.snapshot.accounts.first.username).to eq('alice')
    end

    it 'evaluates ERB before parsing YAML so runtime helpers become effective config' do
      with_config_file(erb_backed_config) do
        ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'runtime-access-token') do
          described_class.reload!
          expect(account_token(described_class.snapshot)).to eq('runtime-access-token')
        end
      end
    end
  end

  describe '.load_snapshot' do
    it 'reparses current config without mutating the memoized runtime snapshot', :aggregate_failures do
      with_config_file(config_for('cached-token')) do |file|
        described_class.reload!

        cached_snapshot = described_class.snapshot

        write_config(file, config_for('fresh-token'))

        expect(described_class.load_snapshot).to have_attributes(
          accounts: contain_exactly(have_attributes(token: 'fresh-token'))
        )
        expect(account_token(described_class.snapshot)).to eq('cached-token')
        expect(account_token(cached_snapshot)).to eq('cached-token')
      end
    end
  end

  def erb_backed_config
    <<~YAML
      auth:
        accounts:
          - username: admin
            token: <%= Html2rss::Web::RuntimeEnv.admin_access_token %>
            allowed_urls:
              - "*"
      feeds: {}
    YAML
  end

  def config_for(token)
    <<~YAML
      auth:
        accounts:
          - username: admin
            token: #{token}
            allowed_urls:
              - "*"
      feeds: {}
    YAML
  end
end
