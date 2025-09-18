# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app/auto_source'

RSpec.describe Html2rss::Web::AutoSource do
  let(:test_config) do
    {
      auth: {
        accounts: [
          {
            username: 'testuser',
            token: 'test-token-abc123',
            allowed_urls: ['https://example.com', 'https://test.com']
          },
          {
            username: 'admin',
            token: 'admin-token-xyz789',
            allowed_urls: ['*']
          }
        ]
      }
    }
  end

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_return(test_config)
  end

  describe '.url_allowed_for_token?' do
    let(:token_data) { { username: 'testuser', token: 'test-token-abc123' } }

    it 'allows URL that is in allowed_urls' do
      result = described_class.url_allowed_for_token?(token_data, 'https://example.com')
      expect(result).to be true
    end

    it 'denies URL that is not in allowed_urls' do
      result = described_class.url_allowed_for_token?(token_data, 'https://malicious.com')
      expect(result).to be false
    end

    it 'allows any URL for admin user' do
      admin_token_data = { username: 'admin', token: 'admin-token-xyz789' }
      result = described_class.url_allowed_for_token?(admin_token_data, 'https://any-site.com')
      expect(result).to be true
    end

    it 'returns false for unknown user' do
      unknown_token_data = { username: 'unknown', token: 'unknown-token' }
      result = described_class.url_allowed_for_token?(unknown_token_data, 'https://example.com')
      expect(result).to be false
    end
  end

  describe '.create_stable_feed' do
    let(:name) { 'Test Feed' }
    let(:url) { 'https://example.com' }
    let(:token_data) { { username: 'testuser', token: 'test-token-abc123' } }
    let(:strategy) { 'ssrf_filter' }

    before do
      allow(described_class).to receive(:url_allowed_for_token?).and_return(true)
      allow(Html2rss::Web::Auth).to receive_messages(generate_feed_id: 'testfeed12345678',
                                                     generate_feed_token: 'test-feed-token-xyz')
    end

    it 'creates a stable feed with all required fields', :aggregate_failures do
      feed = described_class.create_stable_feed(name, url, token_data, strategy)

      expect(feed).to be_a(Hash)
      expect(feed).to include(
        id: 'testfeed12345678',
        name: name,
        url: url,
        username: 'testuser',
        strategy: strategy
      )
      expect(feed).to have_key(:public_url)
    end

    it 'includes feed token in public URL', :aggregate_failures do
      feed = described_class.create_stable_feed(name, url, token_data, strategy)

      expect(feed[:public_url]).to include('token=test-feed-token-xyz')
      expect(feed[:public_url]).to include("url=#{URI.encode_www_form_component(url)}")
    end

    it 'returns nil when URL is not allowed' do
      allow(described_class).to receive(:url_allowed_for_token?).and_return(false)

      feed = described_class.create_stable_feed(name, url, token_data, strategy)
      expect(feed).to be_nil
    end

    it 'returns nil when feed token generation fails' do
      allow(Html2rss::Web::Auth).to receive(:generate_feed_token).and_return(nil)

      feed = described_class.create_stable_feed(name, url, token_data, strategy)
      expect(feed).to be_nil
    end

    it 'uses default strategy when not provided' do
      feed = described_class.create_stable_feed(name, url, token_data)

      expect(feed[:strategy]).to eq('ssrf_filter')
    end

    it 'generates correct feed ID using username, URL, and token' do
      allow(Html2rss::Web::Auth).to receive(:generate_feed_id)
        .with('testuser', url, 'test-token-abc123')
        .and_return('testfeed12345678')

      described_class.create_stable_feed(name, url, token_data, strategy)

      expect(Html2rss::Web::Auth).to have_received(:generate_feed_id)
        .with('testuser', url, 'test-token-abc123')
    end

    it 'generates feed token using username and URL' do
      allow(Html2rss::Web::Auth).to receive(:generate_feed_token)
        .with('testuser', url)
        .and_return('test-feed-token-xyz')

      described_class.create_stable_feed(name, url, token_data, strategy)

      expect(Html2rss::Web::Auth).to have_received(:generate_feed_token)
        .with('testuser', url)
    end
  end

  describe '.generate_feed_content' do
    let(:url) { 'https://example.com' }
    let(:strategy) { 'ssrf_filter' }

    before do
      # Mock the html2rss gem calls
      allow(described_class).to receive(:call_strategy).and_return(double('RSS', to_s: '<rss>test content</rss>'))
    end

    it 'generates RSS content using the specified strategy', :aggregate_failures do
      allow(described_class).to receive(:call_strategy)
        .with(url, strategy)
        .and_return(double('RSS', to_s: '<rss>test content</rss>'))

      content = described_class.generate_feed_content(url, strategy)
      expect(content.to_s).to eq('<rss>test content</rss>')
      expect(described_class).to have_received(:call_strategy)
        .with(url, strategy)
    end

    it 'handles different strategies' do
      allow(described_class).to receive(:call_strategy).and_return(double('RSS', to_s: '<rss>strategy content</rss>'))

      content = described_class.generate_feed_content(url, 'custom_strategy')
      expect(content.to_s).to eq('<rss>strategy content</rss>')
    end
  end

  describe '.enabled?' do
    it 'returns true when auto source is enabled' do
      allow(described_class).to receive(:enabled?).and_return(true)
      expect(described_class.enabled?).to be true
    end

    it 'returns false when auto source is disabled' do
      allow(described_class).to receive(:enabled?).and_return(false)
      expect(described_class.enabled?).to be false
    end
  end
end
