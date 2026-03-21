# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

require_relative '../../../app/web/request/request_context'
require_relative '../../../app/web/security/security_logger'
require_relative '../../../app/web/telemetry/app_logger'
require_relative '../../../app/web/telemetry/log_event'
require_relative '../../../app/web/security/log_sanitizer'
require_relative '../../../app/web/telemetry/observability'

RSpec.describe Html2rss::Web::LogSanitizer do
  let(:io) { StringIO.new }
  let(:logger) { Logger.new(io).tap { |log| log.formatter = Html2rss::Web::AppLogger.send(:method, :format_entry) } }
  let(:context) do
    Html2rss::Web::RequestContext::Context.new(
      request_id: 'req-123',
      path: '/api/v1/feeds/[REDACTED]',
      http_method: 'GET',
      route_group: 'api_v1',
      actor: nil,
      strategy: 'faraday',
      started_at: '2026-03-21T00:00:00Z'
    )
  end

  before do
    Html2rss::Web::RequestContext.set!(context)
    Html2rss::Web::AppLogger.reset_logger!
    Html2rss::Web::SecurityLogger.reset_logger!
    allow(Html2rss::Web::AppLogger).to receive(:logger).and_return(logger)
  end

  after do
    Html2rss::Web::RequestContext.clear!
  end

  it 'redacts feed tokens from token feed request paths', :aggregate_failures do
    expect(described_class.sanitize_path('/api/v1/feeds/token-value-123')).to eq('/api/v1/feeds/[REDACTED]')
    expect(described_class.sanitize_path('/api/v1/feeds/token-value-123.json')).to eq('/api/v1/feeds/[REDACTED].json')
    expect(
      described_class.sanitize_path('/api/v1/feeds/eyJwIjoiYS5iLmMifQ==.xml')
    ).to eq('/api/v1/feeds/[REDACTED].xml')
  end

  it 'replaces logged urls with hashed host metadata' do
    expected_url = {
      host: 'news.ycombinator.com',
      scheme: 'https',
      hash: url_hash('https://news.ycombinator.com')
    }

    expect(described_class.sanitize_details(url: 'https://news.ycombinator.com')).to eq(url: expected_url)
  end

  it 'falls back to a hash for malformed urls' do
    expect(described_class.sanitize_details(url: '://bad url')).to eq(
      url: { hash: Digest::SHA256.hexdigest('://bad url')[0..11] }
    )
  end

  it 'sanitizes nested url fields when emitting shared log events' do
    Html2rss::Web::LogEvent.emit(payload: nested_url_payload)

    payload = JSON.parse(io.string.lines.last, symbolize_names: true)

    expect(payload.slice(:url, :related_urls, :details)).to eq(expected_nested_url_payload)
  end

  it 'sanitizes security logger token usage fields' do
    Html2rss::Web::SecurityLogger.log_token_usage('very-secret-token', 'https://news.ycombinator.com', true)
    payload = JSON.parse(io.string.lines.last, symbolize_names: true)

    expect(payload.slice(:path, :url, :token_hash)).to eq(
      path: '/api/v1/feeds/[REDACTED]',
      url: {
        host: 'news.ycombinator.com',
        scheme: 'https',
        hash: url_hash('https://news.ycombinator.com')
      },
      token_hash: Digest::SHA256.hexdigest('very-secret-token')[0..7]
    )
  end

  it 'sanitizes observability details' do
    Html2rss::Web::Observability.emit(
      event_name: 'feed.render',
      outcome: 'success',
      details: { url: 'https://news.ycombinator.com', strategy: 'faraday' }
    )

    lines = io.string.lines.map { |line| JSON.parse(line, symbolize_names: true) }
    observability_payload = lines.first

    expect(observability_payload.dig(:details, :url)).to eq(
      host: 'news.ycombinator.com',
      scheme: 'https',
      hash: url_hash('https://news.ycombinator.com')
    )
  end

  it 'formats rack-timeout logfmt as json' do
    logger.info('source=rack-timeout id=req-123 timeout=15000ms state=completed')

    payload = JSON.parse(io.string.lines.last, symbolize_names: true)
    expect(payload).to include(
      source: 'rack-timeout',
      id: 'req-123',
      timeout: '15000ms',
      state: 'completed'
    )
  end

  private

  # @return [Hash{Symbol=>Object}]
  def nested_url_payload
    {
      url: 'https://news.ycombinator.com',
      related_urls: ['https://example.com/feed.xml'],
      details: { url: 'https://lobste.rs/s/test' }
    }
  end

  # @return [Hash{Symbol=>Object}]
  def expected_nested_url_payload
    {
      url: sanitized_url('news.ycombinator.com', 'https://news.ycombinator.com'),
      related_urls: [
        sanitized_url('example.com', 'https://example.com/feed.xml')
      ],
      details: {
        url: sanitized_url('lobste.rs', 'https://lobste.rs/s/test')
      }
    }
  end

  # @param host [String]
  # @param url [String]
  # @return [Hash{Symbol=>String}]
  def sanitized_url(host, url)
    { host:, scheme: 'https', hash: url_hash(url) }
  end

  # @param url [String]
  # @return [String]
  def url_hash(url)
    Digest::SHA256.hexdigest(url)[0..11]
  end
end
