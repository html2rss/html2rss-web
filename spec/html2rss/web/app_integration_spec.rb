# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'json'
require_relative '../../../app'

RSpec.describe Html2rss::Web::App do
  include Rack::Test::Methods

  def app = described_class.freeze.app

  FEED_URL = 'https://example.com/articles'
  FEED_TOKEN = 'valid-feed-token'

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

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_return(accounts_config)
    token_payload = instance_double(Html2rss::Web::FeedToken, url: FEED_URL, username: account[:username])
    allow(Html2rss::Web::FeedToken).to receive_messages(
      decode: token_payload,
      validate_and_decode: token_payload
    )
    allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).and_return(account)
    allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(true)
    allow(Html2rss::Web::AutoSource).to receive_messages(enabled?: true,
                                                         generate_feed_content: '<rss version="2.0"></rss>')
  end

  describe 'GET /api/v1/feeds/:token' do
    it 'returns unauthorized for invalid tokens', :aggregate_failures do
      allow(Html2rss::Web::FeedToken).to receive(:decode).and_return(nil)

      get '/api/v1/feeds/invalid-token'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('error' => include('code' => 'UNAUTHORIZED'))
    end

    it 'renders the XML feed with cache headers', :aggregate_failures do
      get "/api/v1/feeds/#{FEED_TOKEN}", {}, 'HTTP_HOST' => 'localhost:3000'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      cache_control = last_response.headers['Cache-Control']
      expect(cache_control).to include('max-age=600')
      expect(cache_control).to include('public')
      expect(last_response.body).to eq('<rss version="2.0"></rss>')
    end

    it 'returns bad request for unsupported strategy', :aggregate_failures do
      get "/api/v1/feeds/#{FEED_TOKEN}", { 'strategy' => 'invalid' }

      expect(last_response.status).to eq(400)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('error' => include('message' => 'Unsupported strategy'))
    end
  end

  describe 'POST /api/v1/feeds' do
    let(:request_payload) do
      {
        url: FEED_URL,
        strategy: 'ssrf_filter'
      }
    end

    let(:created_feed) do
      {
        id: 'feed-123',
        name: 'Example Feed',
        url: FEED_URL,
        strategy: 'ssrf_filter',
        public_url: "/api/v1/feeds/#{FEED_TOKEN}",
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
      allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(false)

      post '/api/v1/feeds', request_payload.to_json, 'CONTENT_TYPE' => 'application/json',
                                                     'HTTP_AUTHORIZATION' => "Bearer #{account[:token]}"

      expect(last_response.status).to eq(403)
      expect(JSON.parse(last_response.body)).to include(
        'error' => include('message' => 'URL not allowed for this account')
      )
    end

    it 'returns bad request for unsupported strategy', :aggregate_failures do
      payload = request_payload.merge(strategy: 'unsupported')

      post '/api/v1/feeds', payload.to_json, 'CONTENT_TYPE' => 'application/json',
                                             'HTTP_AUTHORIZATION' => "Bearer #{account[:token]}"

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)).to include(
        'error' => include('message' => 'Unsupported strategy')
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

      expect(last_response.status).to eq(201)
      response_json = JSON.parse(last_response.body)
      expect(response_json).to include('success' => true)
      expect(response_json.dig('data', 'feed')).to include(
        'id' => 'feed-123',
        'url' => FEED_URL,
        'public_url' => "/api/v1/feeds/#{FEED_TOKEN}"
      )
    end
  end
end
