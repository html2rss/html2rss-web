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

    it 'formats gem log lines as JSON with sanitized message text', :aggregate_failures do
      set_gem_request_context
      Logger.new(io).tap { it.formatter = described_class.gem_formatter }
            .warn('no scraper matched https://x.test/a?token=1 (tried faraday)')
      payload = JSON.parse(io.string)

      expect(payload).to include('level' => 'WARN', 'request_id' => 'req-gem', 'component' => 'html2rss')
      expect(payload['message']).to include('x.test')
      expect(payload['message']).not_to include('token=1')
      expect(payload).not_to have_key('tried')
      expect(payload).not_to have_key('event_name')
    ensure
      Html2rss::Web::RequestContext.clear!
    end

    # rubocop:disable-next RSpec/ExampleLength -- event_name promotion + message sanitize assert
    it 'promotes gem JSON event_name and structured fields', :aggregate_failures do
      set_gem_request_context
      gem_body = {
        event_name: 'auto_source.no_scraper', host: 'x.test', category: 'app_shell',
        message: 'no scraper matched https://x.test/a?token=1 (app-shell)'
      }.to_json
      Logger.new(io).tap { it.formatter = described_class.gem_formatter }.warn(gem_body)
      payload = JSON.parse(io.string)

      expect(payload).to include(
        'event_name' => 'auto_source.no_scraper', 'host' => 'x.test', 'category' => 'app_shell',
        'component' => 'html2rss', 'request_id' => 'req-gem'
      )
      expect(payload['message']).to include('x.test')
      expect(payload['message']).not_to include('token=1')
    ensure
      Html2rss::Web::RequestContext.clear!
    end
  end

  def set_gem_request_context
    Html2rss::Web::RequestContext.set!(
      Html2rss::Web::RequestContext::Context.new(
        request_id: 'req-gem', path: '/api/v1/feeds/[REDACTED]', http_method: 'GET',
        route_group: 'feed_render', actor: nil, strategy: nil,
        started_at: '2026-03-21T00:00:00Z',
        monotonic_start: Process.clock_gettime(Process::CLOCK_MONOTONIC)
      )
    )
  end
end
