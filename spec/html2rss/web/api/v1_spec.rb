# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'
require_relative '../../../../app'

RSpec.describe 'api/v1', openapi: { example_mode: :none }, type: :request do
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app
  def json_feed_error = JSON.parse(last_response.body).slice('version', 'title')

  def feed_result
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: nil,
      message: nil,
      ttl_seconds: 600,
      cache_key: 'feed_result:test',
      error_message: nil
    )
  end

  def service_error_result
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :error,
      payload: nil,
      message: 'Internal Server Error',
      ttl_seconds: 600,
      cache_key: 'feed_result:error',
      error_message: 'upstream timeout'
    )
  end

  def json_feed_service_error_tuple(token)
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(service_error_result)
    get "/api/v1/feeds/#{token}.json"

    [
      last_response.status,
      last_response.content_type,
      last_response.headers['Cache-Control'],
      JSON.parse(last_response.body).fetch('title')
    ]
  end

  def ghost_feed_token
    Html2rss::Web::FeedToken
      .create_with_validation(
        username: 'ghost',
        url: feed_url,
        strategy: 'faraday',
        secret_key: ENV.fetch('HTML2RSS_SECRET_KEY')
      )
      .encode
  end

  def valid_feed_token
    Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')
  end

  def post_feed_request(payload)
    header 'Authorization', "Bearer #{admin_token}"
    header 'Content-Type', 'application/json'
    post '/api/v1/feeds', payload.to_json
  end

  def json_feed_response_for(token)
    stub_json_feed_success
    get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/feed+json' }

    json_feed_headers_tuple
  end

  def stub_json_feed_success
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
    allow(Html2rss::Web::Feeds::JsonRenderer).to receive(:call)
      .and_return('{"version":"https://jsonfeed.org/version/1.1","items":[]}')
  end

  def json_feed_headers_tuple
    [
      last_response.status,
      last_response.content_type,
      last_response.headers['Cache-Control'],
      last_response.headers['Vary']
    ]
  end

  def expected_featured_feeds
    [
      ['/microsoft.com/azure-products.rss', 'Azure product updates',
       'Follow Microsoft Azure product announcements from your own instance.'],
      ['/phys.org/weekly.rss', 'Top science news of the week',
       'Try a high-signal feed with stable weekly headlines from the built-in config set.'],
      ['/softwareleadweekly.com/issues.rss', 'Software Lead Weekly issues',
       'Follow a long-running newsletter archive from the embedded config catalog.']
    ].map { |path, title, description| { 'path' => path, 'title' => title, 'description' => description } }
  end

  around do |example|
    ClimateControl.modify(AUTO_SOURCE_ENABLED: 'true') { example.run }
  end

  after do
    header 'Accept', nil
  end

  let(:health_token) { 'CHANGE_ME_HEALTH_CHECK_TOKEN' }
  let(:admin_token) { 'CHANGE_ME_ADMIN_TOKEN' }
  let(:feed_url) { 'https://example.com/articles' }

  describe 'GET /api/v1', openapi: {
    summary: 'API metadata',
    operation_id: 'getApiMetadata',
    tags: ['Root'],
    security: []
  } do
    it 'returns API information', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      json = expect_success_response(last_response)
      expect(json.dig('data', 'api', 'name')).to eq('html2rss-web API')
    end

    it 'returns OpenAPI document URL in metadata', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'api', 'openapi_url')).to eq('http://example.org/openapi.yaml')
    end

    it 'returns instance feed-creation capability', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'instance', 'feed_creation')).to eq(
        'enabled' => true,
        'access_token_required' => true
      )
    end

    it 'returns featured included feeds for trial runs', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'instance', 'featured_feeds')).to eq(expected_featured_feeds)
    end

    it 'returns API information with trailing slash', :aggregate_failures do
      get '/api/v1/'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      json = expect_success_response(last_response)
      expect(json.dig('data', 'api', 'name')).to eq('html2rss-web API')
    end
  end

  describe 'GET /api/v1/openapi.yaml', openapi: false do
    it 'redirects the versioned OpenAPI path to the public spec', :aggregate_failures do
      get '/api/v1/openapi.yaml'

      expect(last_response.status).to eq(301)
      expect(last_response.headers['Location']).to eq('/openapi.yaml')
    end
  end

  describe 'GET /api/v1/unknown', openapi: false do
    it 'returns a JSON 404 instead of falling through to feed routes', :aggregate_failures do
      get '/api/v1/unknown'

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include(
        'success' => false,
        'error' => include(
          'message' => Html2rss::Web::NotFoundError::DEFAULT_MESSAGE,
          'code' => Html2rss::Web::NotFoundError::CODE
        )
      )
    end
  end

  describe 'GET /api/v1/health', openapi: {
    summary: 'Authenticated health check',
    operation_id: 'getHealthStatus',
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

    it 'returns health status when the configured environment token is valid', :aggregate_failures do
      ClimateControl.modify(HEALTH_CHECK_TOKEN: 'rotated-health-token') do
        allow(Html2rss::Web::Auth).to receive(:authenticate).and_call_original

        header 'Authorization', 'Bearer rotated-health-token'
        get '/api/v1/health'

        expect(last_response.status).to eq(200)
        json = expect_success_response(last_response)
        expect(json.dig('data', 'health', 'status')).to eq('healthy')
      end
    end

    it 'returns error when configuration fails', :aggregate_failures do
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

  describe 'GET /api/v1/health/ready', openapi: {
    summary: 'Readiness probe',
    operation_id: 'getReadinessProbe',
    tags: ['Health'],
    security: []
  } do
    it 'returns readiness status without authentication', :aggregate_failures do
      get '/api/v1/health/ready'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('healthy')
    end
  end

  describe 'GET /api/v1/health/live', openapi: {
    summary: 'Liveness probe',
    operation_id: 'getLivenessProbe',
    tags: ['Health'],
    security: []
  } do
    it 'returns liveness status without authentication', :aggregate_failures do
      get '/api/v1/health/live'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('alive')
    end
  end

  describe 'GET /api/v1/strategies', openapi: {
    summary: 'List extraction strategies',
    operation_id: 'listStrategies',
    tags: ['Strategies'],
    security: []
  } do
    it 'returns available strategies', :aggregate_failures do
      get '/api/v1/strategies'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      expect(json.dig('data', 'strategies')).to be_an(Array)
    end
  end

  describe 'GET /api/v1/feeds/:token', openapi: {
    summary: 'Render feed by token',
    operation_id: 'renderFeedByToken',
    tags: ['Feeds'],
    security: [],
    example_mode: :multiple
  } do
    before do
      stub_const('Html2rss::FeedChannel', Class.new { attr_reader :ttl })
      stub_const('Html2rss::Feed', Class.new { attr_reader :channel })
    end

    it 'returns unauthorized when account not found', :aggregate_failures, openapi: false do
      get "/api/v1/feeds/#{ghost_feed_token}", {}, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/xml')
      expect(last_response.body).to include('Account not found')
    end

    it 'renders feed for a valid token', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).and_return('<rss version="2.0"></rss>')

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'renders json feed for a valid token when requested through Accept', :aggregate_failures do
      status, content_type, cache_control, vary = json_feed_response_for(valid_feed_token)

      expect([status, content_type]).to eq([200, 'application/feed+json'])
      expect(cache_control).to include('max-age=600')
      expect(vary).to include('Accept')
    end

    it 'prefers xml when Accept quality outranks json', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).and_return('<rss version="2.0"></rss>')

      get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/xml;q=1.0, application/feed+json;q=0.2' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'ignores query param strategy overrides', :aggregate_failures, openapi: false do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).and_return('<rss version="2.0"></rss>')

      get "/api/v1/feeds/#{token}", { strategy: 'bad' }, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'returns unauthorized for invalid tokens', :aggregate_failures do
      get '/api/v1/feeds/invalid-token', {}, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/xml')
      expect(last_response.body).to include('Invalid token')
    end

    it 'returns JSON Feed-shaped errors when requested by json extension' do
      get '/api/v1/feeds/invalid-token.json'

      expect([last_response.status, last_response.headers['Content-Type'], json_feed_error]).to eq(
        [401, 'application/feed+json', { 'version' => 'https://jsonfeed.org/version/1.1', 'title' => 'Error' }]
      )
    end

    it 'returns forbidden when auto source is disabled', :aggregate_failures do
      unique_url = "#{feed_url}/disabled"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/xml' }
      end

      expect(last_response.status).to eq(403)
      expect(last_response.content_type).to include('application/xml')
      expect(last_response.body).to include(Html2rss::Web::Api::V1::Contract::MESSAGES[:auto_source_disabled])
    end

    it 'returns JSON Feed-shaped forbidden errors when requested through Accept', :aggregate_failures do
      unique_url = "#{feed_url}/disabled-json"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/feed+json' }
      end

      expect([last_response.status, last_response.headers['Content-Type'], json_feed_error]).to eq(
        [403, 'application/feed+json', { 'version' => 'https://jsonfeed.org/version/1.1', 'title' => 'Error' }]
      )
    end

    it 'returns non-cacheable xml feed errors when service generation fails', :aggregate_failures do
      unique_url = "#{feed_url}/service-error-xml"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(service_error_result)

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(500)
      expect(last_response.content_type).to include('application/xml')
      expect(last_response.headers['Cache-Control']).to include('no-store')
      expect(last_response.body).to include('Internal Server Error')
    end

    it 'returns non-cacheable json feed errors when service generation fails', :aggregate_failures do
      unique_url = "#{feed_url}/service-error-json"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      status, content_type, cache_control, title = json_feed_service_error_tuple(token)

      expect([status, content_type, title]).to eq([500, 'application/feed+json', 'Error'])
      expect(cache_control).to include('no-store')
    end
  end

  describe 'POST /api/v1/feeds', openapi: {
    summary: 'Create a feed',
    operation_id: 'createFeed',
    tags: ['Feeds'],
    security: [{ 'BearerAuth' => [] }]
  } do
    let(:request_params) do
      {
        url: feed_url,
        strategy: 'faraday'
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

    it 'creates a feed when request is valid', :aggregate_failures do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds', request_params.to_json

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect_feed_payload(json)
      expect(last_response.headers['Content-Type']).to include('application/json')
    end

    it 'normalizes hostname-only input to https before feed creation', :aggregate_failures do
      allow(Html2rss::Web::AutoSource).to receive(:create_stable_feed).and_call_original

      post_feed_request(url: 'example.com/articles', strategy: 'faraday')

      expect(Html2rss::Web::AutoSource).to have_received(:create_stable_feed).with(
        anything,
        'https://example.com/articles',
        kind_of(Hash),
        'faraday'
      )

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'feed', 'url')).to eq('https://example.com/articles')
    end

    it 'returns forbidden for authenticated requests when auto source is disabled', :aggregate_failures do
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
