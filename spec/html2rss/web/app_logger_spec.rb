# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Html2rss::Web::AppLogger do
  let(:io) { StringIO.new }
  let(:test_logger) { Logger.new(io).tap { |log| log.formatter = described_class.send(:method, :format_entry) } }

  describe '.logger' do
    it 'writes one JSON line', :aggregate_failures do
      log_event

      payload = JSON.parse(io.string)
      expect(payload).to include(
        'event_name' => 'boot.test',
        'service' => 'html2rss-web'
      )
      expect(payload).not_to have_key('trace_id')
      expect(payload['timestamp']).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/)
    end

    it 'writes one human line in development', :aggregate_failures do
      allow(Html2rss::Web::RuntimeEnv).to receive(:rack_env).and_return('development')

      log_event

      expect(io.string.lines.size).to eq(1)
      expect(io.string).to include('event_name=boot.test')
      expect(io.string).not_to include('{"')
    end

    it 'shares the logger instance across different fibers' do
      described_class.reset_logger!
      logger_a = Fiber.new { described_class.logger }.resume
      logger_b = Fiber.new { described_class.logger }.resume

      expect(logger_a).to be(logger_b)
    end
  end

  def log_event
    allow(Logger).to receive(:new).and_return(test_logger)
    described_class.reset_logger!
    described_class.logger.info({ event_name: 'boot.test', component: 'boot' }.to_json)
  end
end
