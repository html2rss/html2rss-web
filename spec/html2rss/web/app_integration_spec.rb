# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'json'
require_relative '../../../app'

RSpec.describe Html2rss::Web::App do
  include Rack::Test::Methods

  let(:app) { described_class.freeze.app }

  let(:account) do
    {
      username: 'testuser',
      token: 'test-token-abc123',
      allowed_urls: ['https://example.com/*']
    }
  end

  let(:admin_account) do
    {
      username: 'admin',
      token: 'admin-token-xyz789',
      allowed_urls: ['*']
    }
  end

  let(:test_config) do
    {
      auth: {
        accounts: [account, admin_account]
      }
    }
  end

  let(:feed_url) { 'https://example.com/articles' }

  let(:feed_token) { 'valid-feed-token' }

  let(:token_payload) { double('FeedToken', url: feed_url, username: account[:username]) }

  let(:rss_payload) { double('RSS', to_s: '<rss version="2.0"></rss>') }

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_return(test_config)
    allow(Html2rss::Web::AutoSource).to receive_messages(
      enabled?: true,
      allowed_origin?: true
    )
    allow(Html2rss::Web::FeedToken).to receive_messages(
      decode: token_payload,
      validate_and_decode: token_payload
    )
    allow(Html2rss::Web::Auth).to receive_messages(
      get_account_by_username: account,
      url_allowed?: true
    )
    allow(Html2rss::Web::AutoSource).to receive(:generate_feed_content).and_return(rss_payload)
  end

  describe 'GET /api/v1/feeds/:token' do
    it 'returns unauthorized for invalid tokens', :aggregate_failures do
      allow(Html2rss::Web::FeedToken).to receive(:decode).and_return(nil)

      get '/api/v1/feeds/invalid-token'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('error' => include('code' => 'UNAUTHORIZED'))
    end

    it 'returns forbidden when origin is not permitted', :aggregate_failures do
      allow(Html2rss::Web::AutoSource).to receive(:allowed_origin?).and_return(false)

      header 'Host', 'malicious.example'
      get "/api/v1/feeds/#{feed_token}"

      expect(last_response.status).to eq(403)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('error' => include('code' => 'FORBIDDEN'))
    end

    it 'renders the XML feed with cache headers', :aggregate_failures do
      get "/api/v1/feeds/#{feed_token}", {}, 'HTTP_HOST' => 'localhost:3000'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      cache_control = last_response.headers['Cache-Control']
      expect(cache_control).to include('max-age=600')
      expect(cache_control).to include('public')
      expect(last_response.body).to eq('<rss version="2.0"></rss>')
    end
  end

  describe 'POST /api/v1/feeds' do
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
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(account)
      allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_return(created_feed)
    end

    it 'returns bad request when JSON payload is invalid', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(account)

      post '/api/v1/feeds', '{ invalid', 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
      expect(last_response.body).to be_empty
    end

    it 'requires authentication', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)

      post '/api/v1/feeds', request_payload.to_json, 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('error' => include('code' => 'UNAUTHORIZED'))
    end

    it 'denies requests from disallowed origins', :aggregate_failures do
      allow(Html2rss::Web::AutoSource).to receive(:allowed_origin?).and_return(false)

      post '/api/v1/feeds', request_payload.to_json, 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(403)
      expect(JSON.parse(last_response.body)).to include('error' => include('code' => 'FORBIDDEN'))
    end

    it 'returns bad request when URL is missing', :aggregate_failures do
      allow(Html2rss::Web::Api::V1::Feeds).to receive(:extract_site_title).and_return('Example')

      payload = request_payload.merge(url: '')

      post '/api/v1/feeds', payload.to_json, 'CONTENT_TYPE' => 'application/json',
                                             'HTTP_AUTHORIZATION' => "Bearer #{account[:token]}"

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include(
        'error' => include('message' => 'URL parameter is required')
      )
    end

    it 'returns forbidden when URL is not allowed for account', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:url_allowed?).and_return(false)

      post '/api/v1/feeds', request_payload.to_json, 'CONTENT_TYPE' => 'application/json',
                                                     'HTTP_AUTHORIZATION' => "Bearer #{account[:token]}"

      expect(last_response.status).to eq(403)
      expect(JSON.parse(last_response.body)).to include(
        'error' => include('message' => 'URL not allowed for this account')
      )
    end

    it 'returns error when feed creation fails', :aggregate_failures do
      allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_return(nil)

      post '/api/v1/feeds', request_payload.to_json, 'CONTENT_TYPE' => 'application/json',
                                                     'HTTP_AUTHORIZATION' => "Bearer #{account[:token]}"

      expect(last_response.status).to eq(500)
      expect(JSON.parse(last_response.body)).to include(
        'error' => include('message' => 'Failed to create feed')
      )
    end

    it 'returns created feed metadata', :aggregate_failures do
      post '/api/v1/feeds', request_payload.to_json, 'CONTENT_TYPE' => 'application/json',
                                                     'HTTP_AUTHORIZATION' => "Bearer #{account[:token]}"

      expect(last_response.status).to eq(200)
      response_json = JSON.parse(last_response.body)
      expect(response_json).to include('success' => true)
      expect(response_json.dig('data', 'feed')).to include(
        'id' => 'feed-123',
        'url' => feed_url,
        'public_url' => "/api/v1/feeds/#{feed_token}"
      )
    end
  end
end
