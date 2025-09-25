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

  describe 'GET /api/v1/feeds/:token' do
    it 'returns 401 for invalid token', :aggregate_failures do
      get '/api/v1/feeds/invalid-token'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
    end
  end
end
