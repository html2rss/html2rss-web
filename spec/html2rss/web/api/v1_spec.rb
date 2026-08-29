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
      ttl_seconds: 600,
      cache_key: 'feed_result:test',
      error_message: nil,
      empty_reason: nil
    )
  end

  def service_error_result
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :error,
      ttl_seconds: 600,
      cache_key: 'feed_result:error',
      decision: Html2rss::Web::ErrorClassifier::INTERNAL_SERVER_ERROR,
      error_message: 'upstream timeout'
    )
  end

  def empty_result
    empty_feed_result(cache_key: 'feed_result:empty')
  end

  def extraction_empty_result
    empty_feed_result(
      cache_key: 'feed_result:extraction-empty',
      error_message: 'No feed items extracted after auto fallback',
      empty_reason: 'content_extraction_empty'
    )
  end

  # @param cache_key [String]
  # @param error_message [String, nil]
  # @param empty_reason [String]
  # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
  def empty_feed_result(cache_key:, error_message: nil, empty_reason: 'feed_empty')
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :empty,
      payload: empty_feed_payload,
      ttl_seconds: 600,
      cache_key:,
      decision: Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY,
      error_message:,
      empty_reason:
    )
  end

  # @return [Html2rss::Web::Feeds::Contracts::RenderPayload]
  def empty_feed_payload
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: nil,
      site_title: feed_url,
      url: feed_url
    )
  end

  # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
  def ok_feed_result_with_payload
    ok_render_result(feed: link_header_feed_double, cache_key: 'feed_result:link-header')
  end

  def json_feed_service_error_tuple(token)
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(service_error_result)
    get "/api/v1/feeds/#{token}.json"

    [
      last_response.status,
      last_response.content_type,
      last_response.headers['Cache-Control'],
      last_response.body
    ]
  end

  def ghost_feed_token
    token = Html2rss::Web::FeedToken::Signer.create(
      username: 'ghost',
      url: feed_url,
      secret_key: ENV.fetch('HTML2RSS_SECRET_KEY')
    )
    Html2rss::Web::FeedToken::Codec.encode(token)
  end

  def valid_feed_token
    Html2rss::Web::Auth.generate_feed_token('admin', feed_url)
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
    stub_feed_renderer
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
    []
  end

  # @param token [String]
  # @return [String]
  def relative_feed_link_header(token)
    [
      "</api/v1/feeds/#{token}.xml>; rel=\"alternate\"; type=\"application/rss+xml\"",
      "</api/v1/feeds/#{token}.json>; rel=\"alternate\"; type=\"application/feed+json\""
    ].join(', ')
  end

  around do |example|
    ClimateControl.modify(AUTO_SOURCE_ENABLED: 'true') { example.run }
  end

  after do
    header 'Accept', nil
  end

  let(:health_token) { Html2rss::Web::RuntimeEnv.health_check_token }
  let(:admin_token) { 'CHANGE_ME_ADMIN_TOKEN' }
  let(:feed_url) { 'https://example.com/articles' }

  describe 'GET /api/v1', openapi: {
    summary: 'API metadata',
    operation_id: 'getApiMetadata',
    tags: ['Root'],
    security: [{}]
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

    it 'returns catalog pointer metadata', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'instance', 'catalog')).to eq(
        'enabled' => true,
        'url' => 'http://example.org/api/v1/configs'
      )
    end

    it 'returns API information with trailing slash', :aggregate_failures do
      get '/api/v1/'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      json = expect_success_response(last_response)
      expect(json.dig('data', 'api', 'name')).to eq('html2rss-web API')
    end
  end

  describe 'GET /api/v1/configs', openapi: {
    summary: 'Config catalog',
    operation_id: 'getConfigCatalog',
    tags: ['Catalog'],
    security: [{}]
  } do
    # Seed warm last_result rows so OpenAPI infers string|null for code/at
    # (cold-only responses freeze both fields to null).
    before do
      Html2rss::Web::Feeds::LastResults.clear!
      Html2rss::Web::Feeds::LastResults.record(
        'fao.org/newsroom',
        Html2rss::Web::Feeds::Contracts::RenderResult.new(
          status: :ok,
          payload: nil,
          ttl_seconds: 600,
          cache_key: 'feed_result:catalog-openapi'
        ),
        clock: -> { Time.utc(2026, 8, 29, 8) }
      )
      Html2rss::Web::Feeds::LastResults.record(
        'ftc.gov/press-releases',
        Html2rss::Web::Feeds::Contracts::RenderResult.new(
          status: :empty,
          decision: Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY,
          payload: nil,
          ttl_seconds: 600,
          cache_key: 'feed_result:catalog-openapi-empty'
        ),
        clock: -> { Time.utc(2026, 8, 29, 9) }
      )
    end

    after { Html2rss::Web::Feeds::LastResults.clear! }

    it 'returns the merged catalog with CORS headers', :aggregate_failures do
      get '/api/v1/configs'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
      json = expect_success_response(last_response)
      expect(json.dig('meta', 'catalog_version')).to eq(2)
      expect(json.dig('meta', 'starters')).to be_an(Array)
      expect(json.dig('meta', 'starters').size).to be <= 3
      expect(json.dig('data', 'configs')).to be_an(Array)
      expect(json.dig('data', 'configs').first).to include(
        'id', 'path', 'source', 'directory', 'channel', 'parameters', 'last_result'
      )
      expect(json.dig('data', 'configs').first.fetch('last_result')).to include('state', 'code', 'at')
    end

    it 'exposes warm last_result and demotes empty from starters', :aggregate_failures, openapi: false do
      get '/api/v1/configs'

      json = expect_success_response(last_response)
      expect(json.dig('meta', 'starters')).not_to include('ftc.gov/press-releases')
      by_id = json.dig('data', 'configs').to_h { |row| [row.fetch('id'), row] }
      expect(by_id.fetch('fao.org/newsroom').fetch('last_result')).to include(
        'state' => 'ok', 'code' => nil, 'at' => '2026-08-29T08:00:00Z'
      )
      expect(by_id.fetch('ftc.gov/press-releases').fetch('last_result')).to include(
        'state' => 'empty', 'code' => 'EXTRACTION_EMPTY', 'at' => '2026-08-29T09:00:00Z'
      )
    end

    it 'returns 404 when the catalog is disabled', :aggregate_failures do
      ClimateControl.modify(CONFIG_CATALOG_ENABLED: 'false') do
        get '/api/v1/configs'

        expect(last_response.status).to eq(404)
        expect(JSON.parse(last_response.body)).to eq('error' => 'catalog_disabled')
      end
    end
  end

  describe 'OPTIONS /api/v1/configs', openapi: {
    summary: 'Config catalog preflight',
    operation_id: 'optionsConfigCatalog',
    tags: ['Catalog'],
    security: [{}]
  } do
    it 'responds to preflight requests with CORS headers', :aggregate_failures do
      options '/api/v1/configs'

      expect(last_response.status).to eq(204)
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(last_response.headers['Access-Control-Allow-Methods']).to include('GET')
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

    it_behaves_like 'api error contract', {
      status: 401,
      code: Html2rss::Web::UnauthorizedError::CODE,
      kind: 'auth',
      retryable: false,
      next_action: 'enter_token',
      retry_action: 'none'
    }

    it 'returns health status when token is valid', :aggregate_failures do
      header 'Authorization', "Bearer #{health_token}"
      get '/api/v1/health'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'health', 'status')).to eq('healthy')
    end

    it 'returns health status when the configured environment token is valid', :aggregate_failures, openapi: false do
      ClimateControl.modify(HEALTH_CHECK_TOKEN: 'rotated-health-token') do
        allow(Html2rss::Web::Auth).to receive(:authenticate).and_call_original

        header 'Authorization', 'Bearer rotated-health-token'
        get '/api/v1/health'

        expect(last_response.status).to eq(200)
        json = expect_success_response(last_response)
        expect(json.dig('data', 'health', 'status')).to eq('healthy')
      end
    end

    it 'returns health status after production-style env scrubbing', :aggregate_failures, openapi: false do
      capture_scrubbed_runtime_env(
        'RACK_ENV' => 'production',
        'HEALTH_CHECK_TOKEN' => 'scrubbed-health-token'
      ) do
        header 'Authorization', 'Bearer scrubbed-health-token'
        get '/api/v1/health'

        expect(ENV.fetch('HEALTH_CHECK_TOKEN', nil)).to be_nil
        expect(last_response.status).to eq(200)
        json = expect_success_response(last_response)
        expect(json.dig('data', 'health', 'status')).to eq('healthy')
      end
    end

    it 'returns error when configuration fails', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return({ username: 'health-check' })
      allow(Html2rss::Web::LocalConfig).to receive(:load_snapshot).and_raise(StandardError, 'boom')
      header 'Authorization', "Bearer #{health_token}"

      get '/api/v1/health'

      expect(last_response.status).to eq(500)
      json = expect_error_response(last_response,
                                   code: Html2rss::Web::InternalServerError::CODE,
                                   kind: 'server',
                                   retryable: false,
                                   next_action: 'none',
                                   retry_action: 'none')
      expect(json.dig('error', 'message')).to eq(Html2rss::Web::HealthCheckFailedError::DEFAULT_MESSAGE)
    end
  end

  describe 'GET /api/v1/health/ready', openapi: {
    summary: 'Readiness probe',
    operation_id: 'getReadinessProbe',
    tags: ['Health'],
    security: [{}]
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
    security: [{}]
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
    security: [{}]
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
    security: [{}],
    example_mode: :multiple
  } do
    before do
      stub_const('Html2rss::FeedChannel', Class.new { attr_reader :ttl })
      stub_const('Html2rss::Feed', Class.new { attr_reader :channel })
    end

    it 'returns unauthorized when account not found', :aggregate_failures, openapi: false do
      get "/api/v1/feeds/#{ghost_feed_token}", {}, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.body).to include('Account not found')
    end

    it 'renders feed for a valid token', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'returns alternate Link headers for successful feeds', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/link-headers", strategy: 'faraday')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(ok_feed_result_with_payload)

      get "/api/v1/feeds/#{token}.xml", {}, { 'HTTP_HOST' => 'example.test' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Vary']).to include('Accept', 'Host')
      expect(last_response.headers['Link']).to eq(relative_feed_link_header(token))
    end

    it 'uses relative Link targets and varies JSON feed_url by Host', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/host-vary", strategy: 'faraday')
      feed = link_header_feed_double
      allow(Html2rss::Web::Feeds::Service).to receive(:call)
        .and_return(ok_render_result(feed: feed, cache_key: 'feed_result:host-vary'))

      get "/api/v1/feeds/#{token}.json", {}, { 'HTTP_HOST' => 'feeds.example.test' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Vary']).to include('Accept', 'Host')
      expect(last_response.headers['Link']).to eq(relative_feed_link_header(token))
      expect(last_response.headers['Link']).not_to include('feeds.example.test')
      expect(feed).to have_received(:to_json_feed)
        .with(feed_url: "http://feeds.example.test/api/v1/feeds/#{token}.json")
    end

    it 'renders json feed for a valid token when requested through Accept', :aggregate_failures do
      status, content_type, cache_control, vary = json_feed_response_for(valid_feed_token)

      expect([status, content_type]).to eq([200, 'application/feed+json'])
      expect(cache_control).to include('max-age=600')
      expect(vary).to include('Accept', 'Host')
    end

    it 'prefers xml when Accept quality outranks json', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/xml;q=1.0, application/feed+json;q=0.2' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'ignores query param strategy overrides', :aggregate_failures, openapi: false do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}", { strategy: 'bad' }, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'returns unauthorized for invalid tokens', :aggregate_failures do
      get '/api/v1/feeds/invalid-token', {}, { 'HTTP_ACCEPT' => 'application/xml' }

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.body).to include('Invalid token')
    end

    it 'does not expose a feed status endpoint', :aggregate_failures, openapi: false do
      get "/api/v1/feeds/#{valid_feed_token}/status"

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')
      expect(response_json(last_response).dig('error', 'code')).to eq(Html2rss::Web::NotFoundError::CODE)
    end

    it 'returns plain text errors when requested by json extension' do
      get '/api/v1/feeds/invalid-token.json'

      expect([last_response.status, last_response.headers['Content-Type'], last_response.body]).to eq(
        [401, 'text/plain; charset=utf-8', 'Failed to generate feed: Invalid token']
      )
    end

    it 'returns forbidden when auto source is disabled', :aggregate_failures do
      unique_url = "#{feed_url}/disabled"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/xml' }
      end

      expect(last_response.status).to eq(403)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.body).to include(Html2rss::Web::AutoSourceDisabledError::DEFAULT_MESSAGE)
    end

    it 'returns plain text forbidden errors when requested through Accept', :aggregate_failures do
      unique_url = "#{feed_url}/disabled-json"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/feed+json' }
      end

      expect([last_response.status, last_response.headers['Content-Type'], last_response.body]).to eq(
        [403, 'text/plain; charset=utf-8', "Failed to generate feed: #{Html2rss::Web::AutoSourceDisabledError::DEFAULT_MESSAGE}"]
      )
    end

    it 'returns non-cacheable feed errors when service generation fails', :aggregate_failures do
      unique_url = "#{feed_url}/service-error-xml"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(service_error_result)

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(500)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.headers['Cache-Control']).to include('no-store')
      expect(last_response.body).to include('Internal Server Error')
    end

    it 'returns non-cacheable plain text errors when service generation fails for json', :aggregate_failures,
       openapi: false do
      unique_url = "#{feed_url}/service-error-json"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'faraday')

      status, content_type, cache_control, body = json_feed_service_error_tuple(token)

      expect([status, content_type, body]).to eq(
        [500, 'text/plain; charset=utf-8', 'Failed to generate feed: Internal Server Error']
      )
      expect(cache_control).to include('no-store')
    end

    it 'returns 422 for empty extraction feeds in xml representation', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/empty-xml", strategy: 'faraday')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(extraction_empty_result)

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.headers['Cache-Control']).to include('max-age=600')
      expect(last_response.body).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE)
    end

    it 'returns 422 for empty extraction feeds in json feed representation', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/empty-json", strategy: 'faraday')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(extraction_empty_result)

      get "/api/v1/feeds/#{token}.json"

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to eq('text/plain; charset=utf-8')
      expect(last_response.headers['Cache-Control']).to include('max-age=600')
      expect(last_response.body).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE)
    end

    # rubocop:disable RSpec/ExampleLength
    it 'returns 429 when rate limit is exceeded', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive_messages(
        rate_limit_enabled?: true,
        rate_limit_max_requests: 1,
        rate_limit_window_seconds: 60
      )

      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/rate-limited-429", strategy: 'faraday')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}.xml", {}, { 'REMOTE_ADDR' => '192.168.99.1' }
      expect(last_response.status).to eq(200)

      get "/api/v1/feeds/#{token}.xml", {}, { 'REMOTE_ADDR' => '192.168.99.1' }
      expect(last_response.status).to eq(429)
      expect(last_response.headers['Retry-After']).not_to be_nil
    end
    # rubocop:enable RSpec/ExampleLength

    it 'returns 503 when the server times out', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/timeout-503", strategy: 'faraday')
      stub_const('Rack::Timeout::RequestTimeoutException', Class.new(StandardError))

      allow(Html2rss::Web::Feeds::Service).to receive(:call)
        .and_raise(Rack::Timeout::RequestTimeoutException.new('service timeout'))

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(503)
      expect(last_response.headers['Retry-After']).not_to be_nil
    end

    it 'returns 504 when the gateway times out', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/timeout-504", strategy: 'faraday')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_raise(Timeout::Error.new('gateway timeout'))

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(504)
      expect(last_response.headers['Retry-After']).not_to be_nil
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
        url: feed_url
      }
    end

    let(:perform_request) do
      lambda do
        header 'Content-Type', 'application/json'
        post '/api/v1/feeds', request_params.to_json
      end
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
    end

    after do
      header 'Authorization', nil
    end

    it_behaves_like 'api error contract', {
      status: 401,
      code: Html2rss::Web::UnauthorizedError::CODE,
      kind: 'auth',
      retryable: false,
      next_action: 'enter_token',
      retry_action: 'none'
    }

    it 'creates a feed when request is valid', :aggregate_failures do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds', request_params.to_json

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect_feed_payload(json)
      expect(json.fetch('data')).not_to have_key('conversion')
      expect(last_response.headers['Content-Type']).to include('application/json')
    end

    it 'normalizes hostname-only input to https before feed creation', :aggregate_failures do
      post_feed_request(url: 'example.com/articles')

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'feed', 'url')).to eq('https://example.com/articles')
    end

    it 'returns forbidden for authenticated requests when auto source is disabled', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        post '/api/v1/feeds', request_params.to_json
      end

      expect(last_response.status).to eq(403)
      json = expect_error_response(
        last_response,
        code: Html2rss::Web::ForbiddenError::CODE,
        kind: 'input',
        retryable: false,
        next_action: 'correct_input',
        retry_action: 'none'
      )
      expect(json.dig('error', 'message')).to eq(Html2rss::Web::AutoSourceDisabledError::DEFAULT_MESSAGE)
    end

    it 'returns 429 when rate limit is exceeded', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive_messages(
        rate_limit_enabled?: true,
        rate_limit_max_requests: 1,
        rate_limit_window_seconds: 60
      )

      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds', { url: 'https://example.com/articles-post-429' }.to_json, { 'REMOTE_ADDR' => '192.168.99.2' }
      expect(last_response.status).to eq(201)

      post '/api/v1/feeds', { url: 'https://example.com/articles-post-429' }.to_json, { 'REMOTE_ADDR' => '192.168.99.2' }
      expect(last_response.status).to eq(429)
      expect(last_response.headers['Retry-After']).not_to be_nil
    end
  end
end
