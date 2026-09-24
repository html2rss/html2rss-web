# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Feeds::GeneratorInput do
  let(:url) { 'https://example.com/private' }
  let(:global_config) do
    {
      stylesheets: ['/rss.xsl'],
      headers: { 'User-Agent' => 'html2rss-web' },
      ignored: 'not copied'
    }
  end

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(global_config)
  end

  describe '.for_token' do
    it 'reproduces the token generator hash when selectors are absent' do
      expect(described_class.for_token(url:, strategy: 'default')).to eq(
        stylesheets: ['/rss.xsl'],
        headers: { 'User-Agent' => 'html2rss-web' },
        channel: { url: },
        auto_source: {},
        strategy: :default
      )
    end

    it 'merges signed selectors without replacing the token url' do
      selectors = Html2rss::Web::SelectorsDocument.from_client(
        selectors: { items: { selector: 'article', enhance: true } }
      )

      expect(described_class.for_token(url:, strategy: 'default', selectors:)).to include(
        channel: { url: },
        strategy: :default,
        selectors: { items: { selector: 'article', enhance: true } }
      )
    end

    it 'resolves a nil strategy without a caller-supplied name', :aggregate_failures do
      allow(Html2rss::Config).to receive(:default_strategy_name).and_return('botasaurus')

      expect(described_class.for_token(url:)[:strategy]).to eq(:botasaurus)

      allow(Html2rss::Config).to receive(:default_strategy_name).and_return(nil)
      expect(described_class.for_token(url:, strategy: nil)[:strategy]).to eq(:auto)
    end

    it 'rejects an unsupported explicit strategy' do
      expect { described_class.for_token(url:, strategy: 'nope') }
        .to raise_error(Html2rss::Web::BadRequestError, 'Unsupported strategy')
    end

    context 'when serve and preview expand the same token' do
      let(:feed_token) do
        instance_double(Html2rss::Web::FeedToken, username: 'admin', url:, strategy: nil, selectors: nil)
      end
      let(:feed_request) do
        Html2rss::Web::Feeds::Contracts::Request.new(
          target_kind: :token, feed_name: nil, token: 'public-token', params: {}
        )
      end

      before do
        allow(Html2rss::Web::Auth).to receive(:validate_and_decode_feed_token)
          .with('public-token').and_return(feed_token)
        allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username)
          .with('admin').and_return({ username: 'admin' })
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?)
          .with({ username: 'admin' }, url).and_return(true)
        allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(true)
      end

      it 'returns one config for both paths' do
        served = Html2rss::Web::Feeds::SourceResolver.call(feed_request).generator_input

        expect(served).to eq(described_class.for_token(url:))
      end

      it 'returns one config when both paths carry the same selectors' do
        selectors = Html2rss::Web::SelectorsDocument.from_client(selectors: { items: { selector: 'article' } })
        allow(feed_token).to receive(:selectors).and_return(selectors)
        served = Html2rss::Web::Feeds::SourceResolver.call(feed_request).generator_input

        expect(served).to eq(described_class.for_token(url:, selectors:))
      end
    end
  end
end
