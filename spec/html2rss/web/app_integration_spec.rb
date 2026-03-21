# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'cgi'
require 'json'
require 'securerandom'
require_relative '../../../app'

RSpec.describe Html2rss::Web::App, :aggregate_failures do # rubocop:disable RSpec/MultipleMemoizedHelpers
  include Rack::Test::Methods

  let(:app) { described_class.freeze.app }

  let(:feed_url) { 'https://example.com/articles' }
  let(:feed_token) { "valid-feed-token-#{SecureRandom.hex(4)}" }
  let(:encoded_feed_token) { CGI.escape(feed_token) }

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
  let(:json_feed_error) { JSON.parse(last_response.body).slice('version', 'title') }
  let(:feed_result) do
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: nil,
      message: nil,
      ttl_seconds: 600,
      cache_key: 'feed_result:test',
      error_message: nil
    )
  end

  after do
    header 'Accept', nil
  end

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_return(accounts_config)
    stub_const('Html2rss::FeedChannel', Class.new { attr_reader :ttl })
    stub_const('Html2rss::Feed', Class.new { attr_reader :channel })
    token_payload = instance_double(
      Html2rss::Web::FeedToken,
      url: feed_url,
      username: account[:username],
      strategy: 'faraday'
    )
    allow(Html2rss::Web::FeedToken).to receive_messages(
      decode: token_payload,
      validate_and_decode: token_payload
    )
    allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).and_return(account)
    allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(true)
    allow(Html2rss::Web::AutoSource).to receive(:enabled?).and_return(true)
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
    allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).and_return('<rss version="2.0"></rss>')
    allow(Html2rss::Web::Feeds::JsonRenderer).to receive(:call)
      .and_return('{"version":"https://jsonfeed.org/version/1.1","items":[]}')
  end

  describe 'GET /api/v1/feeds/:token' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'returns unauthorized for invalid tokens' do
      allow(Html2rss::Web::FeedToken).to receive(:decode).and_return(nil)

      get '/api/v1/feeds/invalid-token', {}, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/xml')
      expect(last_response.body).to include('Invalid token')
    end

    it 'renders the XML feed with cache headers' do
      get "/api/v1/feeds/#{feed_token}", {}, { 'HTTP_HOST' => 'localhost:3000', 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      cache_control = last_response.headers['Cache-Control']
      expect(cache_control).to include('max-age=600')
      expect(cache_control).to include('public')
      expect(last_response.body).to eq('<rss version="2.0"></rss>')
    end

    it 'accepts URL-escaped public feed tokens' do
      padded_feed_token = 'signed-public-token='
      encoded_padded_feed_token = CGI.escape(padded_feed_token)

      stub_escaped_feed_token(raw_token: padded_feed_token, encoded_token: encoded_padded_feed_token)

      get "/api/v1/feeds/#{encoded_padded_feed_token}", {}, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
    end

    it 'renders the JSON feed when requested by extension' do
      get "/api/v1/feeds/#{feed_token}.json"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/feed+json')
    end

    it 'renders the JSON feed when requested through Accept' do
      get "/api/v1/feeds/#{feed_token}", {}, { 'HTTP_ACCEPT' => 'application/feed+json' }
      expect([last_response.status, last_response.headers['Content-Type']]).to eq([200, 'application/feed+json'])
      expect(last_response.headers['Cache-Control']).to include('max-age=600')
      expect(last_response.headers['Vary']).to include('Accept')
    end

    it 'prefers the path extension over Accept negotiation' do
      header 'Accept', 'application/feed+json'
      get "/api/v1/feeds/#{feed_token}.xml"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
    end

    it 'honors Accept quality values for feed negotiation' do
      header 'Accept', 'application/xml;q=1.0, application/feed+json;q=0.2'
      get "/api/v1/feeds/#{feed_token}"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
    end

    it 'treats wildcard Accept as rss unless json is more specific' do
      header 'Accept', '*/*'
      get "/api/v1/feeds/#{feed_token}"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
    end

    it 'ignores q=0 json feed media types during negotiation' do
      header 'Accept', 'application/feed+json;q=0, application/xml;q=0.4'
      get "/api/v1/feeds/#{feed_token}"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
    end

    it 'serves HEAD requests for token feeds with negotiated headers only' do
      head "/api/v1/feeds/#{feed_token}", {}, { 'HTTP_ACCEPT' => 'application/feed+json' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/feed+json')
      expect(last_response.headers['Cache-Control']).to include('max-age=600')
      expect(last_response.body).to eq('')
    end

    it 'ignores query param strategy overrides' do
      header 'Accept', 'application/xml'
      get "/api/v1/feeds/#{feed_token}", { 'strategy' => 'invalid' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'returns JSON Feed-shaped errors for invalid json feed tokens' do
      allow(Html2rss::Web::FeedToken).to receive(:decode).and_return(nil)

      get '/api/v1/feeds/invalid-token.json'

      expect([last_response.status, last_response.headers['Content-Type'], json_feed_error]).to eq(
        [401, 'application/feed+json', { 'version' => 'https://jsonfeed.org/version/1.1', 'title' => 'Error' }]
      )
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def stub_escaped_feed_token(raw_token:, encoded_token:)
      escaped_token_payload = instance_double(
        Html2rss::Web::FeedToken,
        url: feed_url,
        username: account[:username],
        strategy: 'faraday'
      )

      allow(Html2rss::Web::FeedToken).to receive(:decode).with(raw_token).and_return(escaped_token_payload)
      allow(Html2rss::Web::FeedToken).to receive(:decode).with(encoded_token).and_return(nil)
      allow(Html2rss::Web::FeedToken)
        .to receive(:validate_and_decode).with(raw_token, feed_url, anything)
        .and_return(escaped_token_payload)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end

  describe 'POST /api/v1/feeds' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:request_payload) do
      {
        url: feed_url,
        strategy: 'faraday'
      }
    end

    let(:created_feed) do
      {
        id: 'feed-123',
        name: 'Example Feed',
        url: feed_url,
        strategy: 'faraday',
        feed_token: feed_token,
        public_url: "/api/v1/feeds/#{feed_token}",
        json_public_url: "/api/v1/feeds/#{feed_token}.json",
        username: account[:username]
      }
    end

    before do
      allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_return(created_feed)
    end

    context 'without authentication' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before { allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil) }

      it 'requires authentication' do
        post '/api/v1/feeds', request_payload.to_json, json_headers

        expect(last_response.status).to eq(401)
        expect(last_response.content_type).to include('application/json')
        expect(json_body).to include('error' => include('code' => 'UNAUTHORIZED'))
      end
    end

    context 'with authenticated account' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before { allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(account) }

      it 'returns bad request when JSON payload is invalid' do
        post '/api/v1/feeds', '{ invalid', json_headers

        expect(last_response.status).to eq(400)
        expect(last_response.content_type).to include('application/json')
        expect(json_body).to include('error' => include('message' => 'Invalid JSON payload'))
      end

      it 'returns bad request when URL is missing' do
        allow(Html2rss::Web::Api::V1::FeedMetadata).to receive(:site_title_for).and_return('Example')

        post '/api/v1/feeds', request_payload.merge(url: '').to_json, auth_headers

        expect(last_response.status).to eq(400)
        expect(json_body).to include(
          'error' => include('message' => 'URL parameter is required')
        )
      end

      it 'returns forbidden when URL is not allowed for account' do
        allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(false)

        post '/api/v1/feeds', request_payload.to_json, auth_headers

        expect(last_response.status).to eq(403)
        expect(json_body).to include(
          'error' => include('message' => 'URL not allowed for this account')
        )
      end

      it 'returns bad request for unsupported strategy' do
        post '/api/v1/feeds', request_payload.merge(strategy: 'unsupported').to_json, auth_headers

        expect(last_response.status).to eq(400)
        expect(json_body).to include(
          'error' => include('message' => 'Unsupported strategy')
        )
      end

      it 'returns error when feed creation fails' do
        allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_return(nil)

        post '/api/v1/feeds', request_payload.to_json, auth_headers

        expect(last_response.status).to eq(500)
        expect(json_body).to include(
          'error' => include('message' => 'Failed to create feed')
        )
      end

      it 'returns created feed metadata' do
        post '/api/v1/feeds', request_payload.to_json, auth_headers

        expect(last_response.status).to eq(201)
        expect(json_body).to include('success' => true)
        expect(json_body.dig('data', 'feed')).to include(
          'id' => 'feed-123',
          'url' => feed_url,
          'feed_token' => feed_token,
          'public_url' => "/api/v1/feeds/#{feed_token}",
          'json_public_url' => "/api/v1/feeds/#{feed_token}.json"
        )
      end
    end
  end
end
