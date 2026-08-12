# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

require_relative '../../../app'

RSpec.describe Html2rss::Web::ErrorResponder do
  def build_request(path:, accept: nil, target: nil, rack_errors: StringIO.new)
    env = { 'rack.errors' => rack_errors, Html2rss::Web::RequestTarget::ENV_KEY => target }
    env['HTTP_ACCEPT'] = accept if accept

    instance_double(
      Rack::Request,
      path: path,
      path_info: path,
      env: env,
      get_header: env['HTTP_ACCEPT']
    )
  end

  def respond_with(error:, path:, accept: nil, target: nil, response: Rack::Response.new)
    request = build_request(path:, accept:, target:)
    body = described_class.respond(request:, response:, error:)

    [response, body]
  end

  def api_error_response
    response, body = respond_with(
      error: StandardError.new('boom'),
      path: '/api/v1/feeds',
      target: Html2rss::Web::RequestTarget::API
    )

    [response.status, response['Content-Type'], JSON.parse(body)]
  end

  def extraction_empty_api_error_response
    no_feed_items_extracted = stub_const('Html2rss::NoFeedItemsExtracted', Class.new(Html2rss::Error))
    response, body = respond_with(
      error: no_feed_items_extracted.new('No feed items extracted after auto fallback'),
      path: '/api/v1/feeds',
      target: Html2rss::Web::RequestTarget::API
    )

    [response.status, response['Content-Type'], JSON.parse(body)]
  end

  def legacy_error_response
    response, body = respond_with(
      error: Html2rss::Web::InternalServerError.new('oops'),
      path: '/legacy'
    )

    [response.status, response['Content-Type'], body]
  end

  def json_feed_error_response
    response, body = respond_with(
      error: Html2rss::Web::UnauthorizedError.new('Invalid token'),
      path: '/api/v1/feeds/token.json',
      target: Html2rss::Web::RequestTarget::FEED
    )

    [response.status, response['Content-Type'], body]
  end

  def expected_api_error_response # rubocop:disable Metrics/MethodLength
    [500, 'application/json',
     {
       'success' => false,
       'error' => {
         'code' => Html2rss::Web::InternalServerError::CODE,
         'message' => 'Internal Server Error',
         'kind' => 'server',
         'retryable' => true,
         'next_action' => 'retry',
         'retry_action' => 'primary'
       }
     }]
  end

  describe '.respond' do
    it 'returns json error payload for unexpected api errors' do
      expect(api_error_response).to eq(expected_api_error_response)
    end

    it 'maps extraction-empty api errors to corrective 422 payloads' do
      expect(extraction_empty_api_error_response).to eq(
        [422, 'application/json', extraction_empty_api_payload]
      )
    end

    it 'returns plain text error payload for non-api routes by default' do
      expect(legacy_error_response).to eq([500, 'text/plain; charset=utf-8', 'Failed to generate feed: oops'])
    end

    it 'returns plain text feed errors for json feed routes by default' do
      expect(json_feed_error_response).to eq(
        [401, 'text/plain; charset=utf-8', 'Failed to generate feed: Invalid token']
      )
    end

    it 'maps TooManyRequestsError to 429 and injects Retry-After header', :aggregate_failures do
      response, _body = respond_with(
        error: Html2rss::Web::TooManyRequestsError.new,
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API
      )
      expect(response.status).to eq(429)
      expect(response['Retry-After']).to eq('60')
    end

    it 'maps Rack::Timeout::RequestTimeoutException to 503 and injects Retry-After header', :aggregate_failures do
      stub_const('Rack::Timeout::RequestTimeoutException', Class.new(StandardError))
      response, _body = respond_with(
        error: Rack::Timeout::RequestTimeoutException.new('timeout'),
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API
      )
      expect(response.status).to eq(503)
      expect(response['Retry-After']).to eq('300')
    end

    it 'maps network timeouts to 504 and injects Retry-After header', :aggregate_failures do
      response, _body = respond_with(
        error: Net::OpenTimeout.new('timeout'),
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API
      )
      expect(response.status).to eq(504)
      expect(response['Retry-After']).to eq('300')
    end

    it 'preserves existing Retry-After header for 503 errors', :aggregate_failures do
      existing_response = Rack::Response.new
      existing_response['Retry-After'] = '10'
      response, _body = respond_with(
        error: Html2rss::Web::ServiceUnavailableError.new('service down'),
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API,
        response: existing_response
      )
      expect(response.status).to eq(503)
      expect(response['Retry-After']).to eq('10')
    end

    it 'preserves existing Retry-After header for 504 errors', :aggregate_failures do
      existing_response = Rack::Response.new
      existing_response['Retry-After'] = '10'
      response, _body = respond_with(
        error: Html2rss::Web::GatewayTimeoutError.new('gateway down'),
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API,
        response: existing_response
      )
      expect(response.status).to eq(504)
      expect(response['Retry-After']).to eq('10')
    end
  end

  # @return [Hash{String=>Object}]
  def extraction_empty_api_payload
    {
      'success' => false,
      'error' => extraction_empty_error_fields
    }
  end

  # @return [Hash{String=>Object}]
  def extraction_empty_error_fields
    decision = Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY

    {
      'code' => decision.code,
      'message' => decision.message,
      'kind' => decision.kind,
      'retryable' => decision.retryable,
      'next_action' => decision.next_action,
      'retry_action' => decision.retry_action
    }
  end
end
