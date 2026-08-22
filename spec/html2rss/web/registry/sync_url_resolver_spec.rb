# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::SyncUrlResolver do
  describe '.resolve' do
    it 'uses the GitHub tag release API when pin_version is set', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      tag_api = format(
        described_class::OFFICIAL_GITHUB_TAG_RELEASES_API,
        tag: 'v2026.08.22'
      )
      download_url = 'https://release-assets.githubusercontent.com/registry-bundle.tar.gz'
      stub_request(:get, tag_api).to_return(
        status: 200,
        body: {
          assets: [{ name: described_class::OFFICIAL_ASSET_NAME, browser_download_url: download_url }]
        }.to_json
      )

      entry = Html2rss::Web::Registry::Entry.new(
        id: 'official',
        mode: :sync,
        path: nil,
        sync_channel: Html2rss::Web::Registry::Config::DEFAULT_OFFICIAL_SYNC_CHANNEL,
        sync_url: nil,
        catalog: true,
        public_key_id: 'html2rss:registry:2026',
        public_key: nil,
        sync_policy: Html2rss::Web::Registry::SyncPolicy.new('v2026.08.22', nil, false),
        allowed_channel_domains: []
      )

      expect(described_class.resolve(entry)).to eq(download_url)
    end
  end
end
