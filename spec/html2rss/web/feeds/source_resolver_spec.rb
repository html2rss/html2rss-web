# frozen_string_literal: true

require 'spec_helper'

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
          feed_name: 'legacy',
          token: nil,
          params: { 'page' => '3' }
        )
      end

      before do
        allow(Html2rss::Web::LocalConfig).to receive(:find).with('legacy').and_return(config)
      end

      it 'normalizes the static source into shared generator input without forcing a default strategy',
         :aggregate_failures do
        resolved = described_class.call(feed_request)

        expect(resolved_tuple(resolved)).to match(
          [
            :static,
            start_with('static:legacy:'),
            900,
            include(params: { 'existing' => '1', 'page' => '3' })
          ]
        )
        expect(resolved.generator_input).not_to have_key(:strategy)
        expect(resolved).to have_attributes(url: 'https://example.com/feed', strategy: nil)
      end

      it 'does not mutate the source config hash' do
        described_class.call(feed_request)

        expect(config).to eq(
          channel: { ttl: 15, url: 'https://example.com/feed' },
          params: { 'existing' => '1' }
        )
      end

      it 'preserves an explicit static strategy when configured' do
        config[:strategy] = :botasaurus

        resolved = described_class.call(feed_request)

        expect(resolved.generator_input[:strategy]).to eq(:botasaurus)
        expect(resolved).to have_attributes(url: 'https://example.com/feed', strategy: :botasaurus)
      end

      it 'exposes directory defaults and request params for last-result gating', :aggregate_failures do
        config[:parameters] = { id: { type: 'string', default: 'b006wkfp' } }
        resolved = described_class.call(feed_request)

        expect(resolved).to have_attributes(
          feed_name: 'legacy',
          directory_defaults: { 'id' => 'b006wkfp' },
          request_params: { 'page' => '3' }
        )
      end
    end

    context 'with a token request' do
      let(:feed_request) do
        Html2rss::Web::Feeds::Contracts::Request.new(
          target_kind: :token,
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
          strategy: 'default',
          selectors: nil
        )
      end

      before do
        allow(Html2rss::Web::FeedToken).to receive(:validate)
          .with('public-token').and_return(feed_token)
        allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username)
          .with('admin').and_return({ username: 'admin' })
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?)
          .with({ username: 'admin' }, 'https://example.com/private').and_return(true)
        allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(true)
        allow(Html2rss::RequestService).to receive(:strategy_names).and_return(%i[auto default faraday botasaurus])
        allow(Html2rss::Web::LocalConfig).to receive(:global)
          .and_return({ headers: { 'User-Agent' => 'html2rss-web' } })
      end

      it 'normalizes the token source into shared generator input', :aggregate_failures do
        resolved = described_class.call(feed_request)

        expect(resolved_tuple(resolved)).to match(
          [:token, start_with('token:'), 300,
           include(strategy: :default, channel: { url: 'https://example.com/private' }, auto_source: {})]
        )
        expect(resolved).to have_attributes(
          url: 'https://example.com/private',
          strategy: :default
        )
      end

      it 'accepts legacy faraday token strategy for backwards compatibility' do
        allow(feed_token).to receive(:strategy).and_return('faraday')

        resolved = described_class.call(feed_request)

        expect(resolved.strategy).to eq(:faraday)
      end

      it 'defaults blank token strategy to auto', :aggregate_failures do
        allow(feed_token).to receive(:strategy).and_return(nil)

        resolved = described_class.call(feed_request)

        expect(resolved.generator_input).to include(channel: { url: 'https://example.com/private' }, auto_source: {})
        expect(resolved.generator_input[:strategy]).to eq(:auto)
      end

      it 'defaults blank configured strategy to auto at the generator boundary', :aggregate_failures do
        allow(feed_token).to receive(:strategy).and_return(nil)
        allow(Html2rss::Config).to receive(:default_strategy_name).and_return(nil)

        resolved = described_class.call(feed_request)

        expect(resolved.generator_input[:strategy]).to eq(:auto)
      end

      it 'accepts explicit auto strategy tokens', :aggregate_failures do
        allow(feed_token).to receive(:strategy).and_return('auto')

        resolved = described_class.call(feed_request)

        expect(resolved.generator_input[:strategy]).to eq(:auto)
      end

      it 'rejects unknown explicit token strategies' do
        allow(feed_token).to receive(:strategy).and_return('unknown')

        expect { described_class.call(feed_request) }
          .to raise_error(Html2rss::Web::BadRequestError, 'Unsupported strategy')
      end

      it 'rejects tokens whose account no longer exists' do
        allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username)
          .with('admin').and_return(nil)

        expect { described_class.call(feed_request) }
          .to raise_error(Html2rss::Web::UnauthorizedError, 'Account not found')
      end

      it 'rejects tokens whose URL is no longer allowed' do
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?)
          .with({ username: 'admin' }, 'https://example.com/private').and_return(false)

        expect { described_class.call(feed_request) }
          .to raise_error(Html2rss::Web::ForbiddenError, 'Access Denied')
      end
    end
  end

  describe '.call (boundaries)' do
    def request_for(kind, name: 'legacy', token: nil, params: {})
      Html2rss::Web::Feeds::Contracts::Request.new(target_kind: kind, feed_name: name, token:, params:)
    end

    def static_source(config: { channel: { url: 'https://example.com/feed' } }, **request)
      allow(Html2rss::Web::LocalConfig).to receive(:find).with('legacy').and_return(config)
      described_class.call(request_for(:static, **request))
    end

    it 'rejects unsupported target kinds with the kind in the message' do
      expect { described_class.call(request_for(:weird)) }
        .to raise_error(Html2rss::Web::BadRequestError, 'Unsupported feed target: weird')
    end

    it 'maps unknown static feeds to NotFoundError' do
      allow(Html2rss::Web::LocalConfig).to receive(:find).and_raise(Html2rss::Web::LocalConfig::NotFound)

      expect { described_class.call(request_for(:static)) }.to raise_error(Html2rss::Web::NotFoundError)
    end

    it 'exposes the channel url and configured strategy', :aggregate_failures do
      resolved = static_source(config: { channel: { url: 'https://example.com/feed' }, strategy: :botasaurus })

      expect(resolved).to have_attributes(url: 'https://example.com/feed', strategy: :botasaurus,
                                          source_kind: :static, feed_name: 'legacy')
    end

    it 'defaults the static ttl to one hour and converts feed minutes to seconds', :aggregate_failures do
      expect(static_source.ttl_seconds).to eq(3600)
      expect(static_source(config: { channel: { url: 'https://e.com/', ttl: 2 } }).ttl_seconds).to eq(120)
    end

    it 'keys static cache identity on feed name and params', :aggregate_failures do
      empty = static_source.cache_identity
      with_params = static_source(params: { 'a' => '1', 'b' => '2' }).cache_identity
      reordered = static_source(params: { 'b' => '2', 'a' => '1' }).cache_identity
      other = static_source(params: { 'a' => '1' }).cache_identity

      expect(empty).to eq('static:legacy:empty')
      expect(with_params).to match(/\Astatic:legacy:\h{64}\z/)
      expect(reordered).to eq(with_params)
      expect(other).not_to eq(with_params)
    end

    it 'merges request params over configured params without mutating the config', :aggregate_failures do
      config = { channel: { url: 'https://e.com/' }, params: { 'a' => '1', 'b' => '1' } }
      resolved = static_source(config:, params: { 'b' => '2' })

      expect(resolved.generator_input[:params]).to eq('a' => '1', 'b' => '2')
      expect(config[:params]).to eq('a' => '1', 'b' => '1')
    end

    it 'handles configs without params' do
      expect(static_source(params: { 'x' => '1' }).generator_input[:params]).to eq('x' => '1')
    end

    context 'with tokens' do
      let(:token) { 'tok-abc' }
      let(:feed_token) { Html2rss::Web::FeedToken.new('alice', 'https://example.com/feed', 1, 'sig', nil) }
      let(:account) { { username: 'alice', token: 'x', allowed_urls: ['*'] } }

      before do
        allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(true)
        allow(Html2rss::Web::FeedToken).to receive(:validate).and_return(feed_token)
        allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).and_return(account)
        allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
          stylesheets: [{ href: 's.css' }], headers: { 'X' => '1' }, auth: { accounts: [] }
        )
      end

      def resolve = described_class.call(request_for(:token, name: nil, token:))

      it 'builds a token source with a five minute default ttl and no static metadata', :aggregate_failures do
        expect(resolve).to have_attributes(
          source_kind: :token, ttl_seconds: 300, feed_name: nil, directory_defaults: {}, request_params: {},
          url: 'https://example.com/feed'
        )
      end

      it 'hashes the token into the cache identity' do
        expect(resolve.cache_identity).to eq("token:#{Digest::SHA256.hexdigest(token)}")
      end

      it 'passes only stylesheets and headers from global config', :aggregate_failures do
        input = resolve.generator_input

        expect(input).to include(stylesheets: [{ href: 's.css' }], headers: { 'X' => '1' }, auto_source: {})
        expect(input).not_to have_key(:auth)
        expect(input[:channel]).to eq(url: 'https://example.com/feed')
      end

      it 'fails when auto source is disabled' do
        allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(false)

        expect { resolve }.to raise_error(Html2rss::Web::AutoSourceDisabledError)
      end

      it 'rejects undecodable or invalid tokens' do
        allow(Html2rss::Web::FeedToken).to receive(:validate).and_return(nil)

        expect { resolve }.to raise_error(Html2rss::Web::UnauthorizedError, 'Invalid token')
      end

      it 'rejects tokens for unknown accounts' do
        allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).and_return(nil)

        expect { resolve }.to raise_error(Html2rss::Web::UnauthorizedError, 'Account not found')
      end

      it 'denies urls the account may no longer access' do
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(false)

        expect { resolve }.to raise_error(Html2rss::Web::ForbiddenError, 'Access Denied')
      end

      it 'validates the token url against the token account', :aggregate_failures do
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(true)
        resolve

        expect(Html2rss::Web::UrlValidator).to have_received(:url_allowed?).with(account, 'https://example.com/feed')
        expect(Html2rss::Web::AccountManager).to have_received(:get_account_by_username).with('alice')
      end

      it 'accepts the configured default strategy and trims token strategies', :aggregate_failures do
        allow(Html2rss::Config).to receive(:default_strategy_name).and_return(:custom)
        allow(Html2rss::Web::FeedToken).to receive(:validate)
          .and_return(feed_token.with(strategy: ' custom '))

        expect(resolve.strategy).to eq(:custom)
      end
    end
  end
end
