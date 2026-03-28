# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

require_relative '../../../app/web/config/runtime_env'
require_relative '../../../app/web/telemetry/sentry_logs'
require_relative '../../../app/web/telemetry/app_logger'

RSpec.describe Html2rss::Web::AppLogger do
  let(:io) { StringIO.new }
  let(:test_logger) { Logger.new(io).tap { |log| log.formatter = described_class.send(:method, :format_entry) } }

  describe '.logger' do
    it 'forwards structured logs to the Sentry log bridge', :aggregate_failures do
      allow(Logger).to receive(:new).and_return(test_logger)
      allow(Html2rss::Web::SentryLogs).to receive(:emit)

      described_class.reset_logger!
      described_class.logger.info({ event_name: 'boot.test', component: 'boot' }.to_json)

      expect(Html2rss::Web::SentryLogs).to have_received(:emit).with(
        include(component: 'boot', event_name: 'boot.test', service: 'html2rss-web')
      )
      expect(io.string).to include('"event_name":"boot.test"')
    end

    it 'still writes structured logs when the Sentry bridge raises' do
      allow(Logger).to receive(:new).and_return(test_logger)
      allow(Html2rss::Web::SentryLogs).to receive(:emit).and_raise(StandardError, 'boom')

      described_class.reset_logger!
      expect do
        described_class.logger.info({ event_name: 'boot.test', component: 'boot' }.to_json)
      end.not_to raise_error
      expect(io.string).to include('"event_name":"boot.test"')
    end

    it 'does not forward plain string logs to the Sentry bridge' do
      allow(Logger).to receive(:new).and_return(test_logger)
      allow(Html2rss::Web::SentryLogs).to receive(:emit)

      described_class.reset_logger!
      described_class.logger.info('plain-text log line with request details')

      expect(Html2rss::Web::SentryLogs).not_to have_received(:emit)
      expect(io.string).to include('"message":"plain-text log line with request details"')
    end
  end
end
