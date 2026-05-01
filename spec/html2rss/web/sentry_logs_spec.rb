# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/config/runtime_env'
require_relative '../../../app/web/telemetry/app_logger'
require_relative '../../../app/web/telemetry/sentry_logs'

RSpec.describe Html2rss::Web::SentryLogs do
  let(:logger_class) do
    Struct.new(:captured_call) do
      %i[debug info warn error fatal].each do |log_level|
        define_method(log_level) do |message, **attributes|
          captured_call[:level] = log_level
          captured_call[:message] = message
          captured_call[:attributes] = attributes
        end
      end
    end
  end

  let(:captured_call) { {} }
  let(:sentry_logger) { build_sentry_logger }
  let(:fake_sentry) do
    Module.new.tap do |mod|
      mod.define_singleton_method(:logger) { sentry_logger }
      mod.define_singleton_method(:add_breadcrumb) { |**| nil }
    end
  end
  let(:raw_payload) do
    {
      event_name: 'auth.authenticate',
      actor: 'alice',
      details: {
        username: 'alice',
        ip: '127.0.0.1',
        user_agent: 'curl/8.7.1',
        reason: 'missing_token',
        nested: [{ username: 'bob', ip: '10.0.0.2' }]
      }
    }
  end

  it 'filters auth and security pii before forwarding payloads to Sentry', :aggregate_failures do
    stub_const('Sentry', fake_sentry)
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(sentry_enabled?: true, sentry_logs_enabled?: true)
    allow(described_class).to receive(:logger).and_return(sentry_logger)
    expect(described_class.send(:enabled?)).to be(true)
    described_class.emit(raw_payload)

    expect_forwarded_payload
  end

  it 'does not forward payloads when sentry logs are disabled' do
    stub_const('Sentry', fake_sentry)
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(sentry_enabled?: true, sentry_logs_enabled?: false)
    described_class.emit(raw_payload)

    expect(captured_call).to eq({})
  end

  it 'does not forward payloads when sentry is disabled' do
    stub_const('Sentry', fake_sentry)
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(sentry_enabled?: false, sentry_logs_enabled?: true)
    described_class.emit(raw_payload)

    expect(captured_call).to eq({})
  end

  it 'adds breadcrumbs for request-critical structured logs even when sentry logs are disabled', :aggregate_failures do
    stub_const('Sentry', fake_sentry)
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(sentry_enabled?: true, sentry_logs_enabled?: false)
    allow(Sentry).to receive(:add_breadcrumb)

    Html2rss::Web::AppLogger.send(
      :format_entry,
      'INFO',
      Time.now.utc,
      nil,
      breadcrumb_payload.to_json
    )

    expect(Sentry).to have_received(:add_breadcrumb).with(expected_breadcrumb)
  end

  it 'falls back to info when an unsupported level is requested', :aggregate_failures do
    stub_const('Sentry', fake_sentry)
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(sentry_enabled?: true, sentry_logs_enabled?: true)
    allow(described_class).to receive(:logger).and_return(sentry_logger)

    described_class.emit(raw_payload.merge(level: :unknown_method))

    expect(captured_call).to include(:message, :attributes)
    expect(captured_call.fetch(:message)).to eq('auth.authenticate')
  end

  def build_sentry_logger
    logger_class.new(captured_call)
  end

  def breadcrumb_payload
    {
      event_name: 'feed.create',
      outcome: 'failure',
      request_id: 'req-123',
      route_group: 'api_v1',
      strategy: 'faraday',
      details: { url: 'https://example.com/articles', fallback: 'browserless' }
    }
  end

  def expected_breadcrumb
    include(
      category: 'feed.create',
      message: 'feed.create',
      level: 'info',
      data: breadcrumb_data_matcher
    )
  end

  def breadcrumb_data_matcher
    include(
      event_name: 'feed.create',
      outcome: 'failure',
      request_id: 'req-123',
      route_group: 'api_v1',
      strategy: 'faraday',
      details: breadcrumb_details_matcher
    )
  end

  def breadcrumb_details_matcher
    include(
      url: include(host: 'example.com', scheme: 'https'),
      fallback: 'browserless'
    )
  end

  def expect_forwarded_payload
    expect(captured_call).to include(:message, :attributes)
    expect_forwarded_message
    expect_forwarded_attributes
  end

  def expect_forwarded_message
    expect(captured_call.fetch(:level)).to eq(:info)
    expect(captured_call.fetch(:message)).to eq('auth.authenticate')
  end

  def expect_forwarded_attributes
    attributes = captured_call.fetch(:attributes)
    expect(attributes).to include(event_name: 'auth.authenticate')
    expect(attributes.fetch(:details)).to eq(reason: 'missing_token', nested: [{}])
    expect(attributes).not_to have_key(:actor)
  end
end
