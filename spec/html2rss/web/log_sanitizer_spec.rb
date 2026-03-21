# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

require_relative '../../../app/web/request/request_context'
require_relative '../../../app/web/security/security_logger'
require_relative '../../../app/web/telemetry/app_logger'
require_relative '../../../app/web/telemetry/log_sanitizer'
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
    allow(Html2rss::Web::SecurityLogger).to receive(:logger).and_return(logger)
    allow(Html2rss::Web::Observability).to receive(:logger).and_return(logger)
  end

  after do
    Html2rss::Web::RequestContext.clear!
  end

  it 'redacts feed tokens from token feed request paths' do
    expect(described_class.sanitize_path('/api/v1/feeds/token-value-123')).to eq('/api/v1/feeds/[REDACTED]')
    expect(described_class.sanitize_path('/api/v1/feeds/token-value-123.json')).to eq('/api/v1/feeds/[REDACTED].json')
  end

  it 'replaces logged urls with hashed host metadata' do
    expected_url = {
      host: 'news.ycombinator.com',
      scheme: 'https',
      hash: Digest::SHA256.hexdigest('https://news.ycombinator.com')[0..11]
    }

    expect(described_class.sanitize_details(url: 'https://news.ycombinator.com')).to eq(url: expected_url)
  end

  it 'sanitizes security logger token usage fields' do
    Html2rss::Web::SecurityLogger.log_token_usage('very-secret-token', 'https://news.ycombinator.com', true)
    payload = JSON.parse(io.string.lines.last, symbolize_names: true)

    expect(payload.slice(:path, :url, :token_hash)).to eq(
      path: '/api/v1/feeds/[REDACTED]',
      url: {
        host: 'news.ycombinator.com',
        scheme: 'https',
        hash: Digest::SHA256.hexdigest('https://news.ycombinator.com')[0..11]
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
      hash: Digest::SHA256.hexdigest('https://news.ycombinator.com')[0..11]
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
end
