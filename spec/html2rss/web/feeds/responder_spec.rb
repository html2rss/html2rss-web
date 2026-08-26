# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'
require 'rack'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Responder do
  let(:response) { Rack::Response.new }
  let(:result) do
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: nil,
      ttl_seconds: 600,
      cache_key: 'feed_result:test',
      error_message: nil,
      empty_reason: nil
    )
  end
  let(:static_config) do
    {
      channel: { url: 'https://example.com', ttl: 10 },
      strategy: :faraday
    }
  end

  before do
    allow(Html2rss::Web::Registry::Index.current).to receive(:config_for).with('example').and_return(static_config)
    allow(Html2rss::Web::Observability).to receive(:emit)
    allow(Html2rss::Web::SentryOps).to receive(:emit_failure_telemetry)
  end

  context 'with a cacheable success result' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example', accept: 'application/xml'),
        target_kind: :static,
        identifier: 'example'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Feeds::Renderer).to receive(:render) do |_result, response:, **_kwargs|
        response.status = 200
        response['Content-Type'] = 'application/xml'
        response['Cache-Control'] = 'public, max-age=600'
        response['Vary'] = 'Accept, Host'
        '<rss/>'
      end
    end

    it 'writes the expected response tuple' do
      expect(response_tuple(write_response)).to eq([200, 'application/xml', '<rss/>'])
    end

    it 'resolves the source through the real request and source resolver path', :aggregate_failures do
      write_response

      expect_resolved_static_source
      expect_cache_headers
    end

    it 'emits success after writing the response' do
      write_response

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.render',
        outcome: 'success',
        details: include(strategy: :faraday, url: 'https://example.com', feed_name: 'example'),
        level: :info
      )
    end

    it 'includes scraper status telemetry when FeedResult exposes status', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(status_telemetry_result)
      allow(Html2rss::Web::Feeds::Renderer).to receive(:render) do |_result, response:, **_kwargs|
        response.status = 200
        response['Content-Type'] = 'application/xml'
        '<rss/>'
      end

      described_class.call(
        request: request_for(path: '/example', accept: 'application/xml'),
        target_kind: :static,
        identifier: 'example'
      )

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.render',
        outcome: 'success',
        details: include(scraper_status: status_telemetry_feed.status.to_h),
        level: :info
      )
    end
  end

  context 'with an error result' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example.json', accept: 'application/feed+json'),
        target_kind: :static,
        identifier: 'example.json'
      )
    end

    let(:result) do
      Html2rss::Web::Feeds::Contracts::RenderResult.new(
        status: :error,
        payload: nil,
        ttl_seconds: 600,
        cache_key: 'feed_result:error',
        decision: Html2rss::Web::ErrorClassifier::INTERNAL_SERVER_ERROR,
        error_message: 'timeout',
        empty_reason: nil
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
    end

    it 'writes plain text error responses by default' do
      expect(response_tuple(write_response)).to eq(
        [500, 'text/plain; charset=utf-8', 'Failed to generate feed: Internal Server Error']
      )
    end

    it 'marks the response as non-cacheable', :aggregate_failures do
      write_response

      expect(response['Cache-Control']).to include('no-store')
      expect(response['Vary']).to eq('Accept')
    end

    it 'emits hard error from RenderResult fields including diagnostics', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      attempts = [{ strategy: :faraday, items_count: 0, error_class: 'Timeout::Error' }]
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(
        Html2rss::Web::Feeds::Contracts::RenderResult.new(
          status: :error,
          decision: Html2rss::Web::ErrorClassifier::INTERNAL_SERVER_ERROR,
          ttl_seconds: 600,
          cache_key: 'feed_result:error-diag',
          error_message: 'timeout',
          diagnostics: Html2rss::Web::ErrorClassifier::Diagnostics.from_attempts(attempts)
        )
      )

      write_response

      expect(Html2rss::Web::SentryOps).to have_received(:emit_failure_telemetry).with(
        decision: Html2rss::Web::ErrorClassifier::INTERNAL_SERVER_ERROR,
        diagnostics: have_attributes(strategy_attempts: attempts),
        event_name: 'feed.render',
        details: include(
          strategy: :faraday,
          url: 'https://example.com',
          feed_name: 'example',
          error_code: 'INTERNAL_SERVER_ERROR',
          error_message: 'timeout',
          strategy_attempts: attempts
        ),
        level: :warn,
        context: { url: 'https://example.com', strategy: :faraday }
      )
    end
  end

  context 'with an empty extraction result' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example.json', accept: 'application/feed+json'),
        target_kind: :static,
        identifier: 'example.json'
      )
    end

    let(:result) do
      Html2rss::Web::Feeds::Contracts::RenderResult.new(
        status: :empty,
        payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
          feed: nil,
          site_title: 'https://example.com',
          url: 'https://example.com'
        ),
        ttl_seconds: 600,
        cache_key: 'feed_result:empty',
        decision: Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY,
        empty_reason: 'content_extraction_empty',
        diagnostics: Html2rss::Web::ErrorClassifier::Diagnostics.from_attempts(
          [
            { strategy: :faraday, items_count: 0, error_class: nil },
            { strategy: :botasaurus, items_count: 0, error_class: nil }
          ]
        )
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
    end

    it 'returns 422 with the Decision message by default', :aggregate_failures do
      body = write_response

      expect(response_tuple(body)).to eq([422, 'text/plain; charset=utf-8', body])
      expect(body).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE)
    end

    it 'emits empty extraction as a failure outcome' do
      write_response

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.render',
        outcome: 'failure',
        details: include(
          strategy: :faraday,
          url: 'https://example.com',
          reason: 'content_extraction_empty',
          strategy_attempts: result.diagnostics.strategy_attempts
        ),
        level: :warn
      )
    end
  end

  context 'with an empty feed_empty result' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example.json', accept: 'application/feed+json'),
        target_kind: :static,
        identifier: 'example.json'
      )
    end

    let(:result) do
      Html2rss::Web::Feeds::Contracts::RenderResult.new(
        status: :empty,
        payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
          feed: nil,
          site_title: 'https://example.com',
          url: 'https://example.com'
        ),
        ttl_seconds: 600,
        cache_key: 'feed_result:feed-empty',
        decision: Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY,
        error_message: nil,
        empty_reason: 'feed_empty'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
    end

    it 'emits feed_empty as the failure reason' do
      write_response

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.render',
        outcome: 'failure',
        details: include(strategy: :faraday, url: 'https://example.com', reason: 'feed_empty'),
        level: :warn
      )
    end
  end

  context 'when response rendering fails after feed generation succeeds' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example', accept: 'application/xml'),
        target_kind: :static,
        identifier: 'example'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Feeds::Renderer).to receive(:render).and_raise(StandardError, 'render failed')
    end

    it 'emits only the failure event' do # rubocop:disable RSpec/ExampleLength
      expect { write_response }.to raise_error(StandardError, 'render failed')

      expect(Html2rss::Web::SentryOps).to have_received(:emit_failure_telemetry).once.with(
        decision: Html2rss::Web::ErrorClassifier::INTERNAL_SERVER_ERROR,
        diagnostics: Html2rss::Web::ErrorClassifier::Diagnostics.empty,
        event_name: 'feed.render',
        details: include(
          error_class: 'StandardError',
          error_message: 'render failed',
          error_code: 'INTERNAL_SERVER_ERROR',
          feed_name: 'example'
        ),
        level: :warn
      )
    end
  end

  private

  # @param path [String]
  # @param accept [String]
  # @return [Rack::Request]
  def request_for(path:, accept:)
    rack_response = response

    Rack::Request.new(
      Rack::MockRequest.env_for(path, 'HTTP_ACCEPT' => accept)
    ).tap do |request|
      request.define_singleton_method(:response) { rack_response }
    end
  end

  # @param body [String]
  # @return [Array<(Integer, String, String)>]
  def response_tuple(body)
    [response.status, response['Content-Type'], body]
  end

  # @return [void]
  def expect_resolved_static_source
    expect(Html2rss::Web::Feeds::Service).to have_received(:call).with(
      have_attributes(
        source_kind: :static,
        cache_identity: a_string_starting_with('static:example:'),
        generator_input: include(strategy: :faraday, channel: { url: 'https://example.com', ttl: 10 }),
        ttl_seconds: 600
      )
    )
  end

  # @return [void]
  def expect_cache_headers
    expect(response['Cache-Control']).to include('max-age=600')
    expect(response['Cache-Control']).to include('public')
    expect(response['Vary']).to eq('Accept, Host')
  end

  # @return [Html2rss::FeedResult]
  def status_telemetry_feed
    @status_telemetry_feed ||= instance_double(
      Html2rss::FeedResult,
      empty?: false,
      status: Html2rss::Status.build(articles: [], dedup_dropped: 0)
    )
  end

  # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
  def status_telemetry_result # rubocop:disable Metrics/MethodLength
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
        feed: status_telemetry_feed,
        site_title: 'Example',
        url: 'https://example.com'
      ),
      ttl_seconds: 600,
      cache_key: 'feed_result:status',
      error_message: nil,
      empty_reason: nil
    )
  end
end
