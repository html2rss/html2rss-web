# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

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

  def feed_result_with_site_title(site_title)
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(feed: nil, site_title:, url: feed_url),
      ttl_seconds: 600,
      cache_key: 'feed_result:with-title'
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
    description: 'API metadata',
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

    it 'returns studio capability', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'instance', 'studio')).to eq('enabled' => true)
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
    description: 'Config catalog',
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
    description: 'Config catalog preflight',
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
    description: 'Authenticated health check',
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
    description: 'Readiness probe',
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
    description: 'Liveness probe',
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
    description: 'List extraction strategies',
    operation_id: 'listStrategies',
    tags: ['Strategies'],
    security: [{}]
  } do
    it 'returns available strategies', :aggregate_failures do
      get '/api/v1/strategies'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      json = expect_success_response(last_response)
      strategies = json.dig('data', 'strategies')
      expect(strategies.map { |s| s['id'] }).to eq(%w[default botasaurus])
      expect(strategies.map { |s| s['display_name'] }).to eq(['Default', 'Browser (Botasaurus)'])
    end
  end

  describe 'GET /api/v1/feeds/:token', openapi: {
    summary: 'Render feed by token',
    description: 'Render feed by token',
    operation_id: 'renderFeedByToken',
    tags: ['Feeds'],
    security: [{}]
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
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'default')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'returns alternate Link headers for successful feeds', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/link-headers", strategy: 'default')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(ok_feed_result_with_payload)

      get "/api/v1/feeds/#{token}.xml", {}, { 'HTTP_HOST' => 'example.test' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Vary']).to include('Accept', 'Host')
      expect(last_response.headers['Link']).to eq(relative_feed_link_header(token))
    end

    it 'uses relative Link targets and varies JSON feed_url by Host', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/host-vary", strategy: 'default')
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
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'default')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/xml;q=1.0, application/feed+json;q=0.2' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/xml')
    end

    it 'ignores query param strategy overrides', :aggregate_failures, openapi: false do
      token = Html2rss::Web::Auth.generate_feed_token('admin', feed_url, strategy: 'default')

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
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'default')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/xml' }
      end

      expect(last_response.status).to eq(403)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.body).to include(Html2rss::Web::AutoSourceDisabledError::DEFAULT_MESSAGE)
    end

    it 'returns plain text forbidden errors when requested through Accept', :aggregate_failures do
      unique_url = "#{feed_url}/disabled-json"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'default')

      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        get "/api/v1/feeds/#{token}", {}, { 'HTTP_ACCEPT' => 'application/feed+json' }
      end

      expect([last_response.status, last_response.headers['Content-Type'], last_response.body]).to eq(
        [403, 'text/plain; charset=utf-8', "Failed to generate feed: #{Html2rss::Web::AutoSourceDisabledError::DEFAULT_MESSAGE}"]
      )
    end

    it 'returns non-cacheable feed errors when service generation fails', :aggregate_failures do
      unique_url = "#{feed_url}/service-error-xml"
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'default')

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
      token = Html2rss::Web::Auth.generate_feed_token('admin', unique_url, strategy: 'default')

      status, content_type, cache_control, body = json_feed_service_error_tuple(token)

      expect([status, content_type, body]).to eq(
        [500, 'text/plain; charset=utf-8', 'Failed to generate feed: Internal Server Error']
      )
      expect(cache_control).to include('no-store')
    end

    it 'returns 422 for empty extraction feeds in xml representation', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/empty-xml", strategy: 'default')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(extraction_empty_result)

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to include('text/plain')
      expect(last_response.headers['Cache-Control']).to include('max-age=600')
      expect(last_response.body).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE)
    end

    it 'returns 422 for empty extraction feeds in json feed representation', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/empty-json", strategy: 'default')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(extraction_empty_result)

      get "/api/v1/feeds/#{token}.json"

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to eq('text/plain; charset=utf-8')
      expect(last_response.headers['Cache-Control']).to include('max-age=600')
      expect(last_response.body).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE)
    end

    # rubocop:disable-next RSpec/ExampleLength
    it 'returns 429 when rate limit is exceeded', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive_messages(
        rate_limit_enabled?: true,
        rate_limit_max_requests: 1,
        rate_limit_window_seconds: 60
      )

      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/rate-limited-429", strategy: 'default')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(feed_result)
      stub_feed_renderer

      get "/api/v1/feeds/#{token}.xml", {}, { 'REMOTE_ADDR' => '192.168.99.1' }
      expect(last_response.status).to eq(200)

      get "/api/v1/feeds/#{token}.xml", {}, { 'REMOTE_ADDR' => '192.168.99.1' }
      expect(last_response.status).to eq(429)
      expect(last_response.headers['Retry-After']).not_to be_nil
    end

    it 'returns 503 when the scraper queue times out', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/timeout-503", strategy: 'default')

      error = Html2rss::RequestService::RequestTimedOut.new('queue timed out', timeout_phase: 'queue')
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_raise(error)

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(503)
      expect(last_response.headers['Retry-After']).not_to be_nil
    end

    it 'returns 504 when the gateway times out', :aggregate_failures do
      token = Html2rss::Web::Auth.generate_feed_token('admin', "#{feed_url}/timeout-504", strategy: 'default')

      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_raise(Timeout::Error.new('gateway timeout'))

      get "/api/v1/feeds/#{token}.xml"

      expect(last_response.status).to eq(504)
      expect(last_response.headers['Retry-After']).not_to be_nil
    end
  end

  describe 'POST /api/v1/feeds', openapi: {
    summary: 'Create a feed',
    description: 'Create a feed',
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

    it 'signs optional selectors into the feed token', :aggregate_failures do
      selectors = {
        items: { selector: 'article', enhance: true },
        title: { selector: 'h2', extractor: 'text' },
        url: { selector: 'a', extractor: 'href' },
        published_at: { selector: 'time', extractor: 'text' }
      }
      post_feed_request(url: feed_url, selectors:)

      token = expect_success_response(last_response).dig('data', 'feed', 'feed_token')
      fragment = Html2rss::Web::Auth.validate_and_decode_feed_token(token).selectors.to_config_fragment
      expect(fragment.dig(:selectors, :items, :selector)).to eq('article')
      expect(fragment.dig(:selectors, :title, :extractor)).to eq('text')
    end

    it 'signs pagination selectors into the feed token', :aggregate_failures do
      post_feed_request(url: feed_url, selectors: SelectorsContractFixtures::PAGINATION_INTEGER)

      token = expect_success_response(last_response).dig('data', 'feed', 'feed_token')
      fragment = Html2rss::Web::Auth.validate_and_decode_feed_token(token).selectors.to_config_fragment
      expect(fragment.dig(:selectors, :items, :pagination)).to eq(2)
    end

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

    it 'adopts scraped site_title from Service execution when available', :aggregate_failures do
      allow(Html2rss::Web::Feeds::Service).to receive(:call)
        .and_return(feed_result_with_site_title('Live Scraped Site Title'))

      post_feed_request(url: feed_url)

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'feed', 'name')).to eq('Live Scraped Site Title')
    end

    it 'prefers explicit requested name over scraped site_title', :aggregate_failures do
      allow(Html2rss::Web::Feeds::Service).to receive(:call)
        .and_return(feed_result_with_site_title('Live Scraped Site Title'))

      post_feed_request(url: feed_url, name: 'My Custom Feed Name')

      expect(last_response.status).to eq(201)
      json = expect_success_response(last_response)
      expect(json.dig('data', 'feed', 'name')).to eq('My Custom Feed Name')
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

    it 'rejects client-authored selectors while the studio is disabled', :aggregate_failures, openapi: false do
      ClimateControl.modify(STUDIO_ENABLED: 'false') do
        post_feed_request(url: feed_url, selectors: { items: { selector: 'article' } })
      end

      expect(last_response.status).to eq(403)
      expect(JSON.parse(last_response.body).dig('error', 'message')).to eq('Studio is disabled')
    end

    it 'still creates a url-only feed while the studio is disabled', :aggregate_failures, openapi: false do
      ClimateControl.modify(STUDIO_ENABLED: 'false', AUTO_SOURCE_ENABLED: 'true') do
        post_feed_request(url: feed_url)
      end

      expect(last_response.status).to eq(201)
      expect(expect_success_response(last_response).dig('data', 'feed', 'url')).to eq(feed_url)
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

    it 'returns 400 when request body exceeds maximum allowed bytes', :aggregate_failures do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'

      oversized_payload = { url: 'https://example.com/articles', padding: 'x' * 100_000 }.to_json
      post '/api/v1/feeds', oversized_payload

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json.dig('error', 'message')).to eq('Payload too large')
    end

    it 'returns 400 when form-urlencoded request body exceeds maximum allowed bytes', :aggregate_failures,
       openapi: false do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/x-www-form-urlencoded'

      oversized_payload = "url=https://example.com/articles&#{'x' * 100_000}"
      post '/api/v1/feeds', oversized_payload

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json.dig('error', 'message')).to eq('Payload too large')
    end
  end

  describe 'POST /api/v1/feeds/validate', openapi: {
    summary: 'Validate a selectors document',
    description: 'Validate a selectors document',
    operation_id: 'validateFeedConfig',
    tags: ['Studio'],
    security: [{ 'BearerAuth' => [] }]
  } do
    def post_validate(payload)
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/validate', payload.to_json
    end

    let(:perform_request) do
      lambda {
        header 'Content-Type', 'application/json'
        post '/api/v1/feeds/validate', {
          selectors: { items: { selector: 'article' } },
          url: 'https://example.com/articles'
        }.to_json
      }
    end

    it_behaves_like 'api error contract', {
      status: 401,
      code: Html2rss::Web::UnauthorizedError::CODE,
      kind: 'auth',
      retryable: false,
      next_action: 'enter_token',
      retry_action: 'none'
    }

    it 'returns a structured report for a selectors document', :aggregate_failures do
      selectors = {
        items: { selector: 'article', enhance: true },
        title: { selector: 'h2', extractor: 'text' },
        url: { selector: 'a', extractor: 'href' },
        published_at: { selector: 'time', extractor: 'text' }
      }
      post_validate({ selectors:, url: 'https://example.com/articles' })

      json = expect_success_response(last_response)
      expect(json.dig('data', 'report', 'success')).to be(true)
      expect(json.dig('data', 'selectors', 'items', 'selector')).to eq('article')
      expect(json.dig('data', 'selectors', 'title', 'extractor')).to eq('text')
      expect(json.dig('data', 'selectors', 'url', 'extractor')).to eq('href')
    end

    it 'exports the page url beside the selectors' do
      post_validate({ selectors: { items: { selector: 'article' } }, url: 'https://example.com/articles' })

      json = expect_success_response(last_response)
      exported = YAML.safe_load(json.dig('data', 'yaml'))
      expect(exported.dig('channel', 'url')).to eq(Html2rss::Web::UrlValidator.canonical_url('https://example.com/articles'))
      expect(exported.dig('selectors', 'items', 'selector')).to eq('article')
    end

    it 'rejects an unusable page url' do
      post_validate({ selectors: { items: { selector: 'article' } }, url: 'not a url' })

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body).dig('error', 'message')).to eq('Invalid URL format')
    end

    it 'returns a parse issue for unparseable yaml' do
      post_validate(yaml: "selectors: [\n")

      json = expect_success_response(last_response)
      expect(json.dig('data', 'report', 'issues', 0, 'code')).to eq('parse')
    end

    it 'rejects channel so the token url cannot be replaced' do
      post_validate(yaml: "channel:\n  url: https://evil.example\nselectors:\n  items:\n    selector: article\n")

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body).dig('error', 'message')).to eq('channel is not allowed')
    end
  end

  describe 'POST /api/v1/feeds/preview', openapi: {
    summary: 'Preview a selectors document feed',
    description: 'Preview a selectors document feed',
    operation_id: 'previewFeed',
    tags: ['Studio'],
    security: [{ 'BearerAuth' => [] }]
  } do
    let(:preview_result) do
      Html2rss::Test::Result.new(
        success: true, item_count: 2,
        sample_items: [{
          'title' => 'A',
          'url' => 'https://example.com/a',
          'published_at' => '2026-01-02T03:04:05Z'
        }],
        channel_title: 'Example',
        channel_url: feed_url, strategy_used: :auto, duration_seconds: 0.1, validation_issues: [],
        error_message: nil, failure_kind: nil, rss: '<rss>do-not-leak</rss>'
      )
    end
    let(:failed_preview_result) do
      Html2rss::Test::Result.new(
        success: false, item_count: 0, sample_items: [], channel_title: nil,
        channel_url: feed_url, strategy_used: :auto, duration_seconds: 0.1, validation_issues: [],
        error_message: 'no items', failure_kind: Html2rss::Test::FailureKind.new(name: :min_items), rss: nil,
        quality_report: Html2rss::Test::QualityReport.new(
          warnings: [:short_titles], metrics: { 'short_title_count' => 2 }, native_feed: nil, defer_reason: nil
        )
      )
    end

    def imaged_preview_result
      preview_result.with(
        sample_items: [{ 'title' => 'A' }, { 'title' => 'Plain' }, { 'title' => 'Enclosed' }],
        rss: %(<rss version="2.0"><channel><title>t</title>#{imaged_items}</channel></rss>)
      )
    end

    def imaged_items
      [
        '<item><title>A</title><description>&lt;img src="https://cdn.example/a.jpg"&gt;</description></item>',
        '<item><title>Plain</title><enclosure url="https://cdn.example/b.mp3" type="audio/mpeg" length="1"/></item>',
        '<item><title>Enclosed</title><enclosure url="https://cdn.example/c.jpg" type="image/jpeg" length="2"/></item>'
      ].join
    end

    def capped_preview_result
      rss = %(<rss version="2.0"><channel><title>t</title>#{capped_items}</channel></rss>)
      preview_result.with(item_count: 12, rss:)
    end

    def capped_items
      (1..12).map { |index| capped_item(index) }.join
    end

    def capped_item(index)
      %(<item><title>Item #{index}</title><link>https://example.com/#{index}</link>#{capped_image(index)}</item>)
    end

    def capped_image(index)
      case index
      when 1 then '<description>&lt;img src="https://cdn.example/1.jpg"&gt;</description>'
      when 2 then '<description>&lt;img src="javascript:alert(1)"&gt;</description>'
      when 3 then '<enclosure url="data:image/png;base64,aaaa" type="image/png" length="1"/>'
      when 4 then '<enclosure url="http://cdn.example/4.jpg" type="image/jpeg" length="2"/>'
      else ''
      end
    end

    def expected_capped_rows
      images = ['https://cdn.example/1.jpg', nil, nil, 'http://cdn.example/4.jpg', *Array.new(6)]
      (1..10).map { |index| ["Item #{index}", images[index - 1]] }
    end

    before do
      Html2rss::Web::Api::V1::PreviewPageCache.clear!
      allow(Html2rss).to receive(:test).and_return(preview_result)
    end

    after do
      Html2rss::Web::Api::V1::PreviewPageCache.clear!
    end

    def post_preview(url)
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/preview', { url:, selectors: { items: { selector: 'article' } } }.to_json
    end

    def preview_strategy
      Html2rss::Web::Feeds::GeneratorInput.for_token(url: feed_url, strategy: nil)[:strategy]
    end

    def record_preview_results(results)
      pending = results.dup
      configs = []
      cached_pages = []
      allow(Html2rss).to receive(:test) do |config, **|
        path = config.dig(:request, :local_file_path)
        cached_pages << (path && File.file?(path) ? File.read(path) : nil)
        configs << config
        pending.shift || preview_result
      end
      [configs, cached_pages]
    end

    def kept_page_result
      preview_result.with(response_body: '<html>kept</html>')
    end

    def rejected_page_results
      [
        kept_page_result,
        failed_preview_result.with(response_body: '<html>failed</html>'),
        preview_result.with(response_body: '   '),
        kept_page_result
      ]
    end

    it 'selects test fields and never returns the rss body', :aggregate_failures do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/preview', { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

      json = expect_success_response(last_response)
      expect(json.fetch('data').keys).to contain_exactly(
        'item_count', 'sample_items', 'quality_report', 'failure_kind', 'validation_issues'
      )
      expect(json.dig('data', 'item_count')).to eq(2)
    end

    it 'reports the failure kind and quality report when extraction comes up empty', :aggregate_failures do
      allow(Html2rss).to receive(:test).and_return(failed_preview_result)
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/preview', { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

      json = expect_success_response(last_response)
      expect(json.dig('data', 'failure_kind')).to eq('min_items')
      expect(json.dig('data', 'quality_report', 'warnings')).to eq(['short_titles'])
    end

    it 'adds one image url per sample item and still omits the rss document', :aggregate_failures do
      allow(Html2rss).to receive(:test).and_return(imaged_preview_result)
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/preview', { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

      json = expect_success_response(last_response)
      expect(json.dig('data', 'sample_items').map { it['image'] }).to eq(
        ['https://cdn.example/a.jpg', nil, 'https://cdn.example/c.jpg']
      )
      expect(json.fetch('data').keys).not_to include('rss')
    end

    it 'caps the meadow at ten items and keeps only http(s) images', :aggregate_failures do
      allow(Html2rss).to receive(:test).and_return(capped_preview_result)
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/preview', { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

      json = expect_success_response(last_response)
      samples = json.dig('data', 'sample_items')
      expect(json.dig('data', 'item_count')).to eq(12)
      expect(samples.map { it.values_at('title', 'image') }).to eq(expected_capped_rows)
    end

    it 'keeps gem samples when the rss document cannot be parsed', :aggregate_failures do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/preview', { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

      json = expect_success_response(last_response)
      expect(json.dig('data', 'sample_items', 0, 'title')).to eq('A')
      expect(json.dig('data', 'sample_items', 0)).not_to have_key('image')
    end

    it 'replays the same url from the cached page and fetches a different url', :aggregate_failures do
      configs, pages = record_preview_results([kept_page_result, kept_page_result, kept_page_result])
      post_preview(feed_url)
      post_preview(feed_url)
      post_preview('https://other.example/news')

      expect(configs.map { it[:strategy] }).to eq([preview_strategy, :local_file, preview_strategy])
      expect(pages[1]).to eq('<html>kept</html>')
    end

    it 'removes the temp file when the cache is cleared' do
      configs, = record_preview_results([kept_page_result, kept_page_result])
      post_preview(feed_url)
      post_preview(feed_url)
      path = configs[1].dig(:request, :local_file_path)
      Html2rss::Web::Api::V1::PreviewPageCache.clear!

      expect(File.file?(path)).to be(false)
    end

    it 'keeps the stored page when a later body is empty or failed', :aggregate_failures do
      configs, pages = record_preview_results(rejected_page_results)
      post_preview(feed_url)
      post_preview(feed_url)
      post_preview('https://other.example/empty')
      post_preview(feed_url)

      expect(configs.map { it[:strategy] }).to eq([preview_strategy, :local_file, preview_strategy, :local_file])
      expect(pages.values_at(1, 3)).to eq(['<html>kept</html>', '<html>kept</html>'])
    end

    it 'previews through the token generator config' do
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      selectors = Html2rss::Web::SelectorsDocument.from_client(selectors: { items: { selector: 'article' } })
      post '/api/v1/feeds/preview', { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

      expect(Html2rss).to have_received(:test).with(
        Html2rss::Web::Feeds::GeneratorInput.for_token(url: feed_url, selectors:),
        min_items: 1
      )
    end
  end

  describe 'POST /api/v1/feeds/suggest_selectors', openapi: {
    summary: 'Suggest selectors for a page',
    description: 'Suggest selectors for a page',
    operation_id: 'suggestSelectors',
    tags: ['Studio'],
    security: [{ 'BearerAuth' => [] }]
  } do
    def ranked_candidates
      {
        items: [
          { selector: 'article', enhance: false, sample: 'First story' },
          { selector: '.story', enhance: true, sample: 'Second story' }
        ],
        title: [{ selector: 'h2', sample: 'First story' }],
        link: [{ selector: 'a', sample: 'First story' }],
        published: [{ selector: 'time', sample: 'Yesterday' }]
      }
    end

    def wire_candidates
      {
        'items' => [
          { 'selector' => 'article', 'enhance' => false, 'sample' => 'First story' },
          { 'selector' => '.story', 'enhance' => true, 'sample' => 'Second story' }
        ],
        'title' => [{ 'selector' => 'h2', 'sample' => 'First story' }],
        'link' => [{ 'selector' => 'a', 'sample' => 'First story' }],
        'published' => [{ 'selector' => 'time', 'sample' => 'Yesterday' }]
      }
    end

    def empty_candidates = { items: [], title: [], link: [], published: [] }

    def empty_wire_candidates
      { 'items' => [], 'title' => [], 'link' => [], 'published' => [] }
    end

    def capture_double(candidates, admission_drops: { 'chrome' => 2 })
      instance_double(
        Html2rss::Capture::CaptureResult,
        segment_strategy: :list,
        admission_drops:,
        candidates:
      )
    end

    def post_suggest
      header 'Authorization', "Bearer #{admin_token}"
      header 'Content-Type', 'application/json'
      post '/api/v1/feeds/suggest_selectors', { url: feed_url, items_selector: 'h2' }.to_json
    end

    before { Html2rss::Web::Api::V1::PreviewPageCache.clear! }
    after { Html2rss::Web::Api::V1::PreviewPageCache.clear! }

    it 'returns empty candidate buckets as success', :aggregate_failures do
      allow(Html2rss).to receive(:capture).and_return(capture_double(empty_candidates, admission_drops: {}))
      post_suggest

      json = expect_success_response(last_response)
      expect(last_response.status).to eq(200)
      expect(json.dig('data', 'candidates')).to eq(empty_wire_candidates)
    end

    it 'returns ranked selector candidates', :aggregate_failures do
      allow(Html2rss).to receive(:capture).and_return(capture_double(ranked_candidates))
      post_suggest

      json = expect_success_response(last_response)
      expect(last_response.status).to eq(200)
      expect(json.fetch('data')).to eq(
        'candidates' => wire_candidates,
        'segment_strategy' => 'list',
        'admission_drops' => { 'chrome' => 2 }
      )
    end

    it 'replays the cached preview page instead of capturing live', :aggregate_failures do
      page = '<html><body><article>Cached</article></body></html>'
      result = instance_double(Html2rss::Test::Result, success: true, response_body: page)
      Html2rss::Web::Api::V1::PreviewPageCache.store(feed_url, result)
      path = Html2rss::Web::Api::V1::PreviewPageCache.path_for(feed_url)
      allow(Html2rss).to receive(:capture).and_return(capture_double(empty_candidates, admission_drops: {}))

      post_suggest

      expect(Html2rss).to have_received(:capture).with(
        feed_url,
        hash_including(strategy: :auto, items_selector: 'h2', local_file_path: path)
      )
      expect(path).to be_a(String)
      expect(File.read(path)).to eq(page)
    end

    it 'captures live when the preview cache has no matching URL', :aggregate_failures do
      allow(Html2rss).to receive(:capture).and_return(capture_double(empty_candidates, admission_drops: {}))

      post_suggest

      expect(Html2rss).to have_received(:capture).with(
        feed_url,
        hash_including(strategy: :auto, items_selector: 'h2')
      )
      expect(Html2rss).not_to have_received(:capture).with(anything, hash_including(:local_file_path))
    end

    def raise_empty_capture!
      allow(Html2rss).to receive(:capture).and_raise(
        Html2rss::NoFeedItemsExtracted.new(attempts: [{ strategy: :default, items_count: 0, error_class: nil }])
      )
    end

    it 'returns EXTRACTION_EMPTY Decision JSON when capture finds no items', :aggregate_failures do
      raise_empty_capture!
      post_suggest

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include(
        'success' => false,
        'error' => include(
          'code' => Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_CODE,
          'message' => Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE
        )
      )
    end

    it 'returns EXTRACTION_EMPTY JSON in development instead of the exception page', :aggregate_failures do
      raise_empty_capture!

      ClimateControl.modify('RACK_ENV' => 'development') do
        post_suggest
      end

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body).dig('error', 'code')).to eq(
        Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_CODE
      )
      expect(last_response.body).not_to include('NoFeedItemsExtracted')
      expect(last_response.body).not_to include('auto_fallback.rb')
    end
  end

  describe 'studio POSTs with STUDIO_ENABLED=false', openapi: false do
    around do |example|
      ClimateControl.modify(STUDIO_ENABLED: 'false') { example.run }
    end

    Html2rss::Web::Routes::ApiV1::FeedRoutes::STUDIO_POSTS.each_key do |path|
      it "returns 403 for POST /api/v1/feeds/#{path}", :aggregate_failures do
        header 'Authorization', "Bearer #{admin_token}"
        header 'Content-Type', 'application/json'
        post "/api/v1/feeds/#{path}", { url: feed_url, selectors: { items: { selector: 'article' } } }.to_json

        expect(last_response.status).to eq(403)
        expect(JSON.parse(last_response.body).dig('error', 'message')).to eq('Studio is disabled')
      end
    end
  end
end
