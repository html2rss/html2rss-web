# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::SourceResolver do
  describe '.call' do
    def resolved_tuple(resolved)
      [resolved.source_kind, resolved.cache_identity, resolved.ttl_seconds, resolved.generator_input]
    end

    context 'with a static request' do
      let(:config) do
        {
          channel: { ttl: 15, url: 'https://example.com/feed' },
          params: { 'existing' => '1' }
        }
      end

      let(:feed_request) do
        Html2rss::Web::Feeds::Contracts::Request.new(
          target_kind: :static,
          representation: Html2rss::Web::FeedResponseFormat::RSS,
          feed_name: 'legacy',
          token: nil,
          params: { 'page' => '3' }
        )
      end

      before do
        allow(Html2rss::Web::LocalConfig).to receive(:find).with('legacy').and_return(config)
      end

      it 'normalizes the static source into shared generator input', :aggregate_failures do
        resolved = described_class.call(feed_request)

        expect(resolved_tuple(resolved)).to match(
          [
            :static,
            start_with('static:legacy:'),
            900,
            include(params: { 'existing' => '1', 'page' => '3' }, strategy: :faraday)
          ]
        )
      end

      it 'does not mutate the source config hash' do
        described_class.call(feed_request)

        expect(config).to eq(
          channel: { ttl: 15, url: 'https://example.com/feed' },
          params: { 'existing' => '1' }
        )
      end

      it 'preserves an explicit static strategy when configured' do
        config[:strategy] = :browserless

        resolved = described_class.call(feed_request)

        expect(resolved.generator_input[:strategy]).to eq(:browserless)
      end
    end

    context 'with a token request' do
      let(:feed_request) do
        Html2rss::Web::Feeds::Contracts::Request.new(
          target_kind: :token,
          representation: Html2rss::Web::FeedResponseFormat::RSS,
          feed_name: nil,
          token: 'public-token',
          params: {}
        )
      end
      let(:feed_token) do
        instance_double(
          Html2rss::Web::FeedToken,
          username: 'admin',
          url: 'https://example.com/private',
          strategy: 'faraday'
        )
      end

      before do
        allow(Html2rss::Web::Auth).to receive(:validate_and_decode_feed_token)
          .with('public-token').and_return(feed_token)
        allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username)
          .with('admin').and_return({ username: 'admin' })
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?)
          .with({ username: 'admin' }, 'https://example.com/private').and_return(true)
        allow(Html2rss::Web::AutoSource).to receive(:enabled?).and_return(true)
        allow(Html2rss::RequestService).to receive(:strategy_names).and_return([:faraday])
        allow(Html2rss::Web::LocalConfig).to receive(:global)
          .and_return({ headers: { 'User-Agent' => 'html2rss-web' } })
      end

      it 'normalizes the token source into shared generator input', :aggregate_failures do
        resolved = described_class.call(feed_request)

        expect(resolved_tuple(resolved)).to match(
          [:token, start_with('token:'), 300,
           include(strategy: :faraday, channel: { url: 'https://example.com/private' }, auto_source: {})]
        )
      end
    end
  end
end
