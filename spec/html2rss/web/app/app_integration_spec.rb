# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::App do
  include Rack::Test::Methods

  let(:app) { described_class.freeze.app }
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
    allow(Html2rss::Web::AutoSource).to receive_messages(
      generate_feed_content: double('RSS', to_s: '<rss>test content</rss>'),
      enabled?: true
    )
  end

  describe 'POST /auto_source/create' do
    let(:valid_params) do
      {
        'url' => 'https://example.com',
        'name' => 'Test Feed'
      }
    end

    context 'with valid authentication' do
      before do
        header 'Authorization', 'Bearer test-token-abc123'
      end

      it 'creates a feed successfully', :aggregate_failures do
        post '/auto_source/create', valid_params

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')

        response_data = JSON.parse(last_response.body)
        expect(response_data).to include(
          'id' => be_a(String),
          'name' => 'Test Feed',
          'url' => 'https://example.com',
          'username' => 'testuser',
          'strategy' => 'ssrf_filter'
        )
        expect(response_data).to have_key('public_url')
        expect(response_data['public_url']).to include('token=')
        expect(response_data['public_url']).to include('url=https%3A%2F%2Fexample.com')
      end

      it 'rejects disallowed URLs', :aggregate_failures do
        post '/auto_source/create', valid_params.merge('url' => 'https://malicious.com')

        expect(last_response.status).to eq(403)
        expect(last_response.body).to include('Access Denied')
      end

      it 'handles missing URL parameter', :aggregate_failures do
        post '/auto_source/create', valid_params.except('url')

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('URL parameter required')
      end

      it 'handles missing name parameter by auto-generating one', :aggregate_failures do
        post '/auto_source/create', valid_params.except('name')

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')

        response_data = JSON.parse(last_response.body)
        expect(response_data).to include(
          'id' => be_a(String),
          'name' => 'Auto-generated feed for https://example.com',
          'url' => 'https://example.com',
          'username' => 'testuser',
          'strategy' => 'ssrf_filter'
        )
      end
    end

    context 'with invalid authentication' do
      before do
        header 'Authorization', 'Bearer invalid-token'
      end

      it 'returns 401 unauthorized', :aggregate_failures do
        post '/auto_source/create', valid_params

        expect(last_response.status).to eq(401)
        expect(last_response.body).to include('Unauthorized')
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized', :aggregate_failures do
        post '/auto_source/create', valid_params

        expect(last_response.status).to eq(401)
        expect(last_response.body).to include('Unauthorized')
      end
    end
  end

  describe 'GET /feeds/:feed_id' do
    let(:feed_id) { 'testfeed12345678' }
    let(:url) { 'https://example.com' }

    context 'with valid feed token' do
      let(:feed_token) do
        # Generate a valid token for testing
        allow(Html2rss::Web::Auth).to receive(:generate_feed_token).and_return('valid-feed-token')
        'valid-feed-token'
      end

      it 'serves the RSS feed', :aggregate_failures do
        allow(Html2rss::Web::Auth).to receive(:feed_url_allowed?).and_return(true)

        get "/feeds/#{feed_id}?token=#{feed_token}&url=#{URI.encode_www_form_component(url)}"

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/xml')
        expect(last_response.body).to include('<rss>test content</rss>')
      end

      it 'rejects requests with wrong URL', :aggregate_failures do
        allow(Html2rss::Web::Auth).to receive(:feed_url_allowed?).and_return(false)

        get "/feeds/#{feed_id}?token=#{feed_token}&url=#{URI.encode_www_form_component('https://malicious.com')}"

        expect(last_response.status).to eq(403)
        expect(last_response.body).to include('Access Denied')
      end
    end

    context 'with invalid feed token' do
      it 'returns 403 forbidden', :aggregate_failures do
        get "/feeds/#{feed_id}?token=invalid-token&url=#{URI.encode_www_form_component(url)}"

        expect(last_response.status).to eq(403)
        expect(last_response.body).to include('Access Denied')
      end
    end

    context 'without feed token (legacy authentication)' do
      before do
        header 'Authorization', 'Bearer test-token-abc123'
      end

      it 'serves the RSS feed with legacy auth', :aggregate_failures do
        get "/feeds/#{feed_id}?url=#{URI.encode_www_form_component(url)}"

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/xml')
        expect(last_response.body).to include('<rss>test content</rss>')
      end

      it 'rejects requests with disallowed URL', :aggregate_failures do
        get "/feeds/#{feed_id}?url=#{URI.encode_www_form_component('https://malicious.com')}"

        expect(last_response.status).to eq(403)
        expect(last_response.body).to include('Access Denied')
      end
    end

    context 'without any authentication' do
      it 'returns 401 unauthorized', :aggregate_failures do
        # Ensure Auth.authenticate returns nil (no authentication)
        allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)

        # Add cache-busting parameter to avoid cached responses
        get "/feeds/#{feed_id}?url=#{URI.encode_www_form_component(url)}&_t=#{Time.now.to_i}"

        expect(last_response.status).to eq(401)
        expect(last_response.body).to include('Unauthorized')
      end
    end

    context 'with missing URL parameter' do
      it 'returns 400 bad request', :aggregate_failures do
        get "/feeds/#{feed_id}?token=valid-token"

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('URL parameter required')
      end
    end
  end

  describe 'error handling' do
    it 'handles internal server errors gracefully', :aggregate_failures do
      allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_raise(StandardError, 'Test error')

      header 'Authorization', 'Bearer test-token-abc123'
      post '/auto_source/create', { 'url' => 'https://example.com', 'name' => 'Test' }

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('Test error')
    end
  end
end
