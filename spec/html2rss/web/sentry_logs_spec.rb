# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/config/runtime_env'
require_relative '../../../app/web/telemetry/sentry_logs'

RSpec.describe Html2rss::Web::SentryLogs do
  let(:captured_call) { {} }
  let(:sentry_logger) { build_sentry_logger }
  let(:fake_sentry) do
    Module.new.tap do |mod|
      mod.define_singleton_method(:logger) { sentry_logger }
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
    allow(described_class).to receive_messages(enabled?: true, logger: sentry_logger)

    described_class.emit(raw_payload)

    expect_forwarded_payload
  end

  def build_sentry_logger
    logger_class = Struct.new(:captured_call) do
      def info(message, **attributes)
        captured_call[:message] = message
        captured_call[:attributes] = attributes
      end
    end

    logger_class.new(captured_call).tap do |logger|
      allow(logger).to receive(:info).and_call_original
    end
  end

  def expect_forwarded_payload
    expect(sentry_logger).to have_received(:info)
    expect_forwarded_message
    expect_forwarded_attributes
  end

  def expect_forwarded_message
    expect(captured_call.fetch(:message)).to eq('auth.authenticate')
  end

  def expect_forwarded_attributes
    attributes = captured_call.fetch(:attributes)
    expect(attributes).to include(event_name: 'auth.authenticate')
    expect(attributes.fetch(:details)).to eq(reason: 'missing_token', nested: [{}])
    expect(attributes).not_to have_key(:actor)
  end
end
