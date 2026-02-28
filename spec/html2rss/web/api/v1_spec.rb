# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'
require_relative '../../../../app'

RSpec.describe 'api/v1', openapi: { example_mode: :none }, type: :request do
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  around do |example|
    ClimateControl.modify(AUTO_SOURCE_ENABLED: 'true') { example.run }
  end

  let(:health_token) { 'health-check-token-xyz789' }
  let(:admin_token) { 'allow-any-urls-abcd-4321' }
  let(:feed_url) { 'https://example.com/articles' }

  describe 'GET /api/v1', openapi: { summary: 'API metadata', tags: ['Root'] } do
    it 'returns API information', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      json = expect_success_response(last_response)
      expect(json.dig('data', 'api', 'name')).to eq('html2rss-web API')
    end
  end

  describe 'GET /api/v1/health', openapi: {
    summary: 'Authenticated health check',
    tags: ['Health'],
    security: [{ 'BearerAuth' => [] }]
  } do
    after do
      header 'Authorization', nil
    end

    let(:perform_request) { -> { get '/api/v1/health' } }

    it_behaves_like 'api error contract',
                    status: 401,
                    code: Html2rss::Web::Api::V1::Contract::CODES[:unauthorized]

    it 'returns health status when token is valid', :aggregate_failures do
      header 'Authorization', "Bearer #{health_token}"
      get '/api/v1/health'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('healthy')
    end

    it 'returns error when configuration fails', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return({ username: 'health-check' })
      allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_raise(StandardError, 'boom')
      header 'Authorization', "Bearer #{health_token}"

      get '/api/v1/health'

      expect(last_response.status).to eq(500)
      json = expect_error_response(last_response,
                                   code: Html2rss::Web::Api::V1::Contract::CODES[:internal_server_error])
      expect(json.dig('error', 'message')).to eq(Html2rss::Web::Api::V1::Contract::MESSAGES[:health_check_failed])
    end
  end

  describe 'GET /api/v1/health/ready', openapi: { summary: 'Readiness probe', tags: ['Health'] } do
    it 'returns readiness status without authentication', :aggregate_failures do
      get '/api/v1/health/ready'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('healthy')
    end
  end

  describe 'GET /api/v1/health/live', openapi: { summary: 'Liveness probe', tags: ['Health'] } do
    it 'returns liveness status without authentication', :aggregate_failures do
      get '/api/v1/health/live'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('alive')
    end
  end

  describe 'GET /api/v1/strategies', openapi: { summary: 'List extraction strategies', tags: ['Strategies'] } do
    it 'returns available strategies', :aggregate_failures do
      get '/api/v1/strategies'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      expect(json.dig('data', 'strategies')).to be_an(Array)
    end
  end

  describe 'GET /api/v1/feeds/:token', openapi: { summary: 'Render feed by token', tags: ['Feeds'] } do
    before do
      stub_const('Html2rss::FeedChannel', Class.new { attr_reader :ttl })
      stub_const('Html2rss::Feed', Class.new { attr_reader :channel })
    end

    it 'returns unauthorized when account not found', :aggregate_failures, openapi: false do # rubocop:disable RSpec/ExampleLength
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

    it 'renders feed for a valid token', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'ssrf_filter')

      allow(Html2rss::Web::AutoSource).to receive(:generate_feed_object)
        .and_return(
          instance_double(Html2rss::Feed, channel: instance_double(Html2rss::FeedChannel, ttl: 10))
        )
      allow(Html2rss::Web::FeedGenerator).to receive(:process_feed_content)
        .and_return('<rss version="2.0"></rss>')

      get "/api/v1/feeds/#{token}"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'ignores query param strategy overrides', :aggregate_failures, openapi: false do # rubocop:disable RSpec/ExampleLength
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

    it 'returns unauthorized for invalid tokens', :aggregate_failures do
      get '/api/v1/feeds/invalid-token'

      expect(last_response.status).to eq(401)
      expect_error_response(last_response, code: 'UNAUTHORIZED')
    end

    it 'returns forbidden when auto source is disabled', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      unique_url = "#{feed_url}/disabled"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'ssrf_filter')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}"
      end

      expect(last_response.status).to eq(403)
      expect_error_response(last_response, code: Html2rss::Web::Api::V1::Contract::CODES[:forbidden])
    end
  end

  describe 'POST /api/v1/feeds', openapi: {
    summary: 'Create a feed',
    tags: ['Feeds'],
    security: [{ 'BearerAuth' => [] }]
  } do
    let(:request_params) do
      {
        url: feed_url,
        strategy: 'ssrf_filter'
      }
    end

    let(:perform_request) do
      lambda do
        header 'Content-Type', 'application/json'
        post '/api/v1/feeds', request_params.to_json
      end
    end

    after do
      header 'Authorization', nil
    end

    it_behaves_like 'api error contract',
                    status: 401,
                    code: Html2rss::Web::Api::V1::Contract::CODES[:unauthorized]

    it 'creates a feed when request is valid', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds', request_params.to_json

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect_feed_payload(json)
      expect(last_response.headers['Content-Type']).to include('application/json')
    end

    it 'returns forbidden for authenticated requests when auto source is disabled', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        post '/api/v1/feeds', request_params.to_json
      end

      expect(last_response.status).to eq(403)
      json = expect_error_response(last_response, code: Html2rss::Web::Api::V1::Contract::CODES[:forbidden])
      expect(json.dig('error', 'message')).to eq(Html2rss::Web::Api::V1::Contract::MESSAGES[:auto_source_disabled])
    end
  end
end
