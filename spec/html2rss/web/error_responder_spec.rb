# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

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
    response, body = respond_with(
      error: Html2rss::NoFeedItemsExtracted.new(attempts: []),
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
    it 'captures a non-http internal error in Sentry' do
      sentry = stub_sentry

      respond_with(error: StandardError.new('boom'), path: '/api/v1/feeds', target: Html2rss::Web::RequestTarget::API)

      expect(sentry).to have_received(:capture_exception)
    end

    it 'does not capture an HttpError classified as internal' do
      sentry = stub_sentry

      respond_with(
        error: Html2rss::Web::InternalServerError.new('oops'),
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API
      )

      expect(sentry).not_to have_received(:capture_exception)
    end

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

    it 'maps Async::TimeoutError to 504 and injects Retry-After header', :aggregate_failures do
      require 'async'
      response, _body = respond_with(
        error: Async::TimeoutError.new,
        path: '/api/v1/feeds',
        target: Html2rss::Web::RequestTarget::API
      )
      expect(response.status).to eq(504)
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

  # @return [Class]
  def stub_sentry
    sentry = stub_const('Sentry', Class.new { def self.capture_exception(_error) = nil })
    allow(sentry).to receive(:capture_exception).and_call_original
    allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(true)
    sentry
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

  describe 'Retry-After handling' do
    it 'defaults 429 responses to the rate limit window', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive(:rate_limit_window_seconds).and_return(42)
      response, = respond_with(error: Html2rss::Web::TooManyRequestsError.new, path: '/x')

      expect(response['Retry-After']).to eq('42')
    end

    it 'keeps a Retry-After header the caller already set' do
      response = Rack::Response.new
      response['Retry-After'] = '7'
      respond_with(error: Html2rss::Web::TooManyRequestsError.new, path: '/x', response:)

      expect(response['Retry-After']).to eq('7')
    end

    it 'uses the timeout retry for 503 and 504', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive(:retry_after_timeout_seconds).and_return(9)
      [Html2rss::Web::ServiceUnavailableError, Html2rss::Web::GatewayTimeoutError].each do |klass|
        response, = respond_with(error: klass.new, path: '/x')
        expect(response['Retry-After']).to eq('9')
      end
    end

    it 'sets no Retry-After for other statuses' do
      response, = respond_with(error: Html2rss::Web::BadRequestError.new('x'), path: '/x')

      expect(response['Retry-After']).to be_nil
    end
  end

  describe 'rendering target selection' do
    it 'renders plain text for the feed target even on api paths' do
      response, body = respond_with(error: StandardError.new('b'), path: '/api/v1/feeds/x',
                                    target: Html2rss::Web::RequestTarget::FEED)

      expect([response['Content-Type'], body]).not_to include('application/json')
    end

    it 'renders JSON for api paths without a target and plain text elsewhere', :aggregate_failures do
      api, api_body = respond_with(error: StandardError.new('b'), path: '/api/v1/other')
      other, = respond_with(error: StandardError.new('b'), path: '/other')

      expect(api['Content-Type']).to eq('application/json')
      expect(JSON.parse(api_body)).to include('success' => false)
      expect(other['Content-Type']).not_to eq('application/json')
    end

    it 'limits the API payload to the public error fields' do
      _, body = respond_with(error: StandardError.new('b'), path: '/api/v1/x', target: Html2rss::Web::RequestTarget::API)

      expect(JSON.parse(body).fetch('error').keys - %w[code message kind retryable next_action
                                                       retry_action]).to be_empty
    end
  end

  describe 'internal error logging' do
    it 'writes the message with the request id to rack.errors for non-HTTP errors', :aggregate_failures do
      io = StringIO.new
      request = build_request(path: '/x', rack_errors: io)
      request.env['html2rss.request_context'] = Struct.new(:request_id).new('req-1')
      described_class.respond(request:, response: Rack::Response.new, error: StandardError.new('kaboom'))

      expect(io.string).to eq("[request_id=req-1] kaboom\n")
    end

    it 'falls back to the X-Request-Id header and then to the bare message', :aggregate_failures do
      io = StringIO.new
      request = build_request(path: '/x', rack_errors: io)
      allow(request).to receive(:get_header).with('HTTP_X_REQUEST_ID').and_return('hdr-1')
      described_class.respond(request:, response: Rack::Response.new, error: StandardError.new('one'))
      expect(io.string).to eq("[request_id=hdr-1] one\n")

      io2 = StringIO.new
      bare = build_request(path: '/x', rack_errors: io2)
      allow(bare).to receive(:get_header).with('HTTP_X_REQUEST_ID').and_return(nil)
      described_class.respond(request: bare, response: Rack::Response.new, error: StandardError.new('two'))
      expect(io2.string).to eq("two\n")
    end

    it 'does not log HTTP errors' do
      io = StringIO.new
      request = build_request(path: '/x', rack_errors: io)
      described_class.respond(request:, response: Rack::Response.new, error: Html2rss::Web::BadRequestError.new('no'))

      expect(io.string).to be_empty
    end
  end

  describe 'observability' do
    before do
      allow(Html2rss::Web::Observability).to receive(:emit)
      stub_const('Sentry', Module.new { def self.capture_exception(_error) = nil })
      allow(Sentry).to receive(:capture_exception)
    end

    it 'emits a request.error event with decision details', :aggregate_failures do
      respond_with(error: Html2rss::Web::BadRequestError.new('bad'), path: '/x')

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'request.error', outcome: 'failure', level: :error,
        details: hash_including(error_class: 'Html2rss::Web::BadRequestError', error_code: 'BAD_REQUEST',
                                error_message: 'bad', status: 400)
      )
    end

    it 'captures unexpected internal faults in Sentry only when enabled', :aggregate_failures do
      allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(true, false)
      error = StandardError.new('boom')
      respond_with(error:, path: '/x')
      respond_with(error: StandardError.new('quiet'), path: '/x')

      expect(Sentry).to have_received(:capture_exception).with(error).once
    end

    it 'does not report classified non-500 faults to Sentry' do
      allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(true)
      respond_with(error: Html2rss::NoFeedItemsExtracted.new(attempts: []), path: '/x')

      expect(Sentry).not_to have_received(:capture_exception)
    end

    it 'never reports HTTP errors to Sentry' do
      allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(true)
      respond_with(error: Html2rss::Web::BadRequestError.new('x'), path: '/x')

      expect(Sentry).not_to have_received(:capture_exception)
    end

    it 'swallows Sentry failures' do
      allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(true)
      allow(Sentry).to receive(:capture_exception).and_raise(StandardError)

      expect { respond_with(error: StandardError.new('x'), path: '/x') }.not_to raise_error
    end
  end
end
