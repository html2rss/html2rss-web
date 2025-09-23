# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../../app'

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
        expect(last_response.body).to include('url parameter required')
      end
    end
  end
end
