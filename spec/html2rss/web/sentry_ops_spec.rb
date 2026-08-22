# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/config/runtime_env'
require_relative '../../../app/web/errors/error_classifier'
require_relative '../../../app/web/telemetry/observability'
require_relative '../../../app/web/telemetry/sentry_ops'

RSpec.describe Html2rss::Web::SentryOps do
  let(:capture_store) { {} }
  let(:diagnostics) do
    Html2rss::Web::ErrorClassifier::Diagnostics.new(
      strategy_attempts: [],
      request_id: 'req-scrape-42',
      strategy_used: 'botasaurus',
      render_ms: 12_345,
      error_category: 'timeout'
    )
  end
  let(:context) do
    {
      event_name: 'feed.render',
      url: 'https://news.example.com/articles',
      strategy: :botasaurus
    }
  end

  before do
    store = capture_store
    fake_sentry = Module.new
    fake_sentry.define_singleton_method(:capture_message) do |message, **kwargs|
      store.merge!(message:, **kwargs)
    end
    stub_const('Sentry', fake_sentry)
    allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(true)
  end

  Html2rss::Web::SentryOps::OPERATIONAL_CODES.each do |code|
    it "emits a Sentry issue for operational code #{code}", :aggregate_failures do
      described_class.emit_operational_failure(
        decision: operational_decision(code),
        diagnostics:,
        context:
      )

      expect(capture_store).to include(expected_capture_for(code))
    end
  end

  %w[BLOCKED_SURFACE EXTRACTION_EMPTY].each do |code|
    it "does not emit a Sentry issue for product-signal code #{code}" do
      described_class.emit_operational_failure(
        decision: Html2rss::Web::ErrorClassifier.const_get(code),
        diagnostics:,
        context:
      )

      expect(capture_store).to be_empty
    end
  end

  it 'does not emit when Sentry is disabled' do
    allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(false)

    described_class.emit_operational_failure(
      decision: operational_decision('SCRAPER_UNAVAILABLE'),
      diagnostics:,
      context:
    )

    expect(capture_store).to be_empty
  end

  it 'emits observability and sentry for classified failures', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    allow(Html2rss::Web::Observability).to receive(:emit)

    described_class.emit_failure_telemetry(
      decision: operational_decision('SERVICE_UNAVAILABLE'),
      diagnostics:,
      event_name: 'request.error',
      details: { error_code: 'SERVICE_UNAVAILABLE', status: 503 },
      level: :error
    )

    expect(Html2rss::Web::Observability).to have_received(:emit).with(
      event_name: 'request.error',
      outcome: 'failure',
      level: :error,
      details: { error_code: 'SERVICE_UNAVAILABLE', status: 503 }
    )
    expect(capture_store).to include(message: 'request.error: SERVICE_UNAVAILABLE')
  end

  def operational_decision(code)
    Html2rss::Web::ErrorClassifier.const_get(code)
  end

  def expected_capture_for(code) # rubocop:disable Metrics/MethodLength
    {
      message: "feed.render: #{code}",
      level: :error,
      tags: include(
        error_code: code,
        error_category: 'timeout',
        request_id: 'req-scrape-42',
        strategy: :botasaurus,
        strategy_used: 'botasaurus',
        host: 'news.example.com',
        render_ms: 12_345
      ),
      fingerprint: ['html2rss-web', 'timeout', 'news.example.com'],
      extra: include(event_name: 'feed.render', request_id: 'req-scrape-42')
    }
  end
end
