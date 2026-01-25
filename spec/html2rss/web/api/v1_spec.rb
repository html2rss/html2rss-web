# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'
require_relative '../../../../app'

RSpec.describe 'api/v1' do # rubocop:disable RSpec/DescribeClass
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  around do |example|
    ClimateControl.modify(AUTO_SOURCE_ENABLED: 'true') { example.run }
  end

  let(:health_token) { 'health-check-token-xyz789' }
  let(:admin_token) { 'allow-any-urls-abcd-4321' }
  let(:feed_url) { 'https://example.com/articles' }

  describe 'GET /api/v1' do
    it 'returns API information', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      json = expect_success_response(last_response)
      expect(json.dig('data', 'api', 'name')).to eq('html2rss-web API')
    end
  end

  describe 'GET /api/v1/health' do
    after do
      header 'Authorization', nil
    end

    it 'requires bearer token', :aggregate_failures do
      get '/api/v1/health'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
      expect_error_response(last_response, code: 'UNAUTHORIZED')
    end

    it 'returns health status when token is valid', :aggregate_failures do
      header 'Authorization', "Bearer #{health_token}"
      get '/api/v1/health'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('healthy')
    end

    it 'returns error when configuration fails', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_raise(StandardError, 'boom')

      header 'Authorization', "Bearer #{health_token}"
      get '/api/v1/health'

      expect(last_response.status).to eq(500)
      json = expect_error_response(last_response, code: 'INTERNAL_SERVER_ERROR')
      expect(json.dig('error', 'message')).to include('boom')
    end
  end

  describe 'GET /api/v1/feeds/:token' do
    before do
      stub_const('Html2rss::FeedChannel', Class.new { attr_reader :ttl })
      stub_const('Html2rss::Feed', Class.new { attr_reader :channel })
    end

    it 'returns unauthorized when account not found', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      ghost_token = Html2rss::Web::FeedToken
                    .create_with_validation(
                      username: 'ghost',
                      url: feed_url,
                      strategy: 'ssrf_filter',
                      secret_key: ENV.fetch('HTML2RSS_SECRET_KEY')
                    )
                    .encode

      get "/api/v1/feeds/#{ghost_token}"

      expect(last_response.status).to eq(401)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be false
      expect(response_data.dig('error', 'code')).to eq('UNAUTHORIZED')
      expect(response_data.dig('error', 'message')).to eq('Account not found')
    end

    it 'ignores query param strategy overrides', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'ssrf_filter')

      allow(Html2rss::Web::AutoSource).to receive(:generate_feed_object)
        .and_return(
          instance_double(Html2rss::Feed, channel: instance_double(Html2rss::FeedChannel, ttl: 10))
        )
      allow(Html2rss::Web::FeedGenerator).to receive(:process_feed_content)
        .and_return('<rss version="2.0"></rss>')

      get "/api/v1/feeds/#{token}", strategy: 'bad'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end
  end

  describe 'POST /api/v1/feeds' do
    let(:request_params) do
      {
        url: feed_url,
        strategy: 'ssrf_filter'
      }
    end

    after do
      header 'Authorization', nil
    end

    it 'requires authentication', :aggregate_failures do
      post '/api/v1/feeds', request_params

      expect(last_response.status).to eq(401)
      expect_error_response(last_response, code: 'UNAUTHORIZED')
    end

    it 'creates a feed when request is valid', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      header 'Authorization', "Bearer #{admin_token}"
      post '/api/v1/feeds', request_params

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect_feed_payload(json)
      expect(last_response.headers['Content-Type']).to include('application/json')
    end
  end
end
