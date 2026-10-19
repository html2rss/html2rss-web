# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Html2rss::Web::AppLogger do
  let(:io) { StringIO.new }
  let(:test_logger) { Logger.new(io).tap { |log| log.formatter = described_class.send(:method, :format_entry) } }

  describe '.logger' do
    it 'writes one JSON line', :aggregate_failures do
      allow(Logger).to receive(:new).and_return(test_logger)
      described_class.reset_logger!
      described_class.logger.info({ event_name: 'boot.test', component: 'boot' }.to_json)

      payload = JSON.parse(io.string)
      expect(payload).to include(
        'event_name' => 'boot.test',
        'component' => 'boot',
        'service' => 'html2rss-web'
      )
      expect(io.string.lines.size).to eq(1)
    end

    it 'shares the logger instance across different fibers' do
      described_class.reset_logger!
      logger_a = Fiber.new { described_class.logger }.resume
      logger_b = Fiber.new { described_class.logger }.resume

      expect(logger_a).to be(logger_b)
    end
  end
end
