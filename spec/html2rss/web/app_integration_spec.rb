# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'json'
require_relative '../../../app'

RSpec.describe Html2rss::Web::App do # rubocop:disable RSpec/MultipleMemoizedHelpers
  include Rack::Test::Methods

  let(:app) { described_class.freeze.app }

  let(:feed_url) { 'https://example.com/articles' }
  let(:feed_token) { 'valid-feed-token' }

  let(:account) do
    {
      username: 'testuser',
      token: 'test-token-abc123',
      allowed_urls: ['https://example.com/*']
    }
  end

  let(:accounts_config) do
    {
      auth: {
        accounts: [account, { username: 'admin', token: 'admin-token-xyz789', allowed_urls: ['*'] }]
      }
    }
  end

  let(:json_headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:auth_headers) { json_headers.merge('HTTP_AUTHORIZATION' => "Bearer #{account[:token]}") }
  let(:json_body) { JSON.parse(last_response.body) }

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_return(accounts_config)
    stub_const('Html2rss::FeedChannel', Class.new { attr_reader :ttl })
    stub_const('Html2rss::Feed', Class.new { attr_reader :channel })
    token_payload = instance_double(
      Html2rss::Web::FeedToken,
      url: feed_url,
      username: account[:username],
      strategy: 'ssrf_filter'
    )
    allow(Html2rss::Web::FeedToken).to receive_messages(
      decode: token_payload,
      validate_and_decode: token_payload
    )
    allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).and_return(account)
    allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(true)
    feed_channel = instance_double(Html2rss::FeedChannel, ttl: 10)
    feed_object = instance_double(Html2rss::Feed, channel: feed_channel)

    allow(Html2rss::Web::AutoSource).to receive_messages(
      enabled?: true,
      generate_feed_object: feed_object
    )
    allow(Html2rss::Web::FeedGenerator).to receive(:process_feed_content)
      .and_return('<rss version="2.0"></rss>')
  end

  describe 'GET /api/v1/feeds/:token' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'returns unauthorized for invalid tokens', :aggregate_failures do
      allow(Html2rss::Web::FeedToken).to receive(:decode).and_return(nil)

      get '/api/v1/feeds/invalid-token'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
      expect(json_body).to include('error' => include('code' => 'UNAUTHORIZED'))
    end

    it 'renders the XML feed with cache headers', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      get "/api/v1/feeds/#{feed_token}", {}, 'HTTP_HOST' => 'localhost:3000'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      cache_control = last_response.headers['Cache-Control']
      expect(cache_control).to include('max-age=600')
      expect(cache_control).to include('public')
      expect(last_response.body).to eq('<rss version="2.0"></rss>')
    end

    it 'ignores query param strategy overrides', :aggregate_failures do
      get "/api/v1/feeds/#{feed_token}", { 'strategy' => 'invalid' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end
  end

  describe 'POST /api/v1/feeds' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:request_payload) do
      {
        url: feed_url,
        strategy: 'ssrf_filter'
      }
    end

    let(:created_feed) do
      {
        id: 'feed-123',
        name: 'Example Feed',
        url: feed_url,
        strategy: 'ssrf_filter',
        public_url: "/api/v1/feeds/#{feed_token}",
        username: account[:username]
      }
    end

    before do
      allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_return(created_feed)
    end

    context 'without authentication' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before { allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil) }

      it 'requires authentication', :aggregate_failures do
        post '/api/v1/feeds', request_payload.to_json, json_headers

        expect(last_response.status).to eq(401)
        expect(last_response.content_type).to include('application/json')
        expect(json_body).to include('error' => include('code' => 'UNAUTHORIZED'))
      end
    end

    context 'with authenticated account' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before { allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(account) }

      it 'returns bad request when JSON payload is invalid', :aggregate_failures do
        post '/api/v1/feeds', '{ invalid', json_headers

        expect(last_response.status).to eq(400)
        expect(last_response.content_type).to include('application/json')
        expect(json_body).to include('error' => include('message' => 'Invalid JSON payload'))
      end

      it 'returns bad request when URL is missing', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        allow(Html2rss::Web::Api::V1::Feeds).to receive(:extract_site_title).and_return('Example')

        post '/api/v1/feeds', request_payload.merge(url: '').to_json, auth_headers

        expect(last_response.status).to eq(400)
        expect(json_body).to include(
          'error' => include('message' => 'URL parameter is required')
        )
      end

      it 'returns forbidden when URL is not allowed for account', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(false)

        post '/api/v1/feeds', request_payload.to_json, auth_headers

        expect(last_response.status).to eq(403)
        expect(json_body).to include(
          'error' => include('message' => 'URL not allowed for this account')
        )
      end

      it 'returns bad request for unsupported strategy', :aggregate_failures do
        post '/api/v1/feeds', request_payload.merge(strategy: 'unsupported').to_json, auth_headers

        expect(last_response.status).to eq(400)
        expect(json_body).to include(
          'error' => include('message' => 'Unsupported strategy')
        )
      end

      it 'returns error when feed creation fails', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_return(nil)

        post '/api/v1/feeds', request_payload.to_json, auth_headers

        expect(last_response.status).to eq(500)
        expect(json_body).to include(
          'error' => include('message' => 'Failed to create feed')
        )
      end

      it 'returns created feed metadata', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        post '/api/v1/feeds', request_payload.to_json, auth_headers

        expect(last_response.status).to eq(201)
        expect(json_body).to include('success' => true)
        expect(json_body.dig('data', 'feed')).to include(
          'id' => 'feed-123',
          'url' => feed_url,
          'public_url' => "/api/v1/feeds/#{feed_token}"
        )
      end
    end
  end
end
