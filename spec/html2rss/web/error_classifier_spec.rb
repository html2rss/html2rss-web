# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::ErrorClassifier do
  def stub_no_feed_items_extracted
    stub_const('Html2rss::NoFeedItemsExtracted', Class.new(Html2rss::Error))
  end

  def stub_no_feed_items_extracted_with_attempts
    stub_const('Html2rss::NoFeedItemsExtracted', Class.new(Html2rss::Error) do
      def initialize(attempts:)
        @attempts = attempts
        super('No feed items extracted after auto fallback')
      end

      attr_reader :attempts
    end)
  end

  def stub_request_timed_out
    stub_const('Html2rss::RequestService::RequestTimedOut', Class.new(Html2rss::Error) do
      def initialize(message = nil, timeout_phase: nil)
        @timeout_phase = timeout_phase
        super(message)
      end

      attr_reader :timeout_phase
    end)
  end

  describe '.classify' do
    it 'returns a carried Decision without remapping' do
      decided = described_class::DecidedError.new(described_class::BLOCKED_SURFACE)

      expect(described_class.classify(decided)).to eq(described_class::BLOCKED_SURFACE)
    end

    it 'returns the extraction-empty decision for NoFeedItemsExtracted' do
      klass = stub_no_feed_items_extracted

      expect(described_class.classify(klass.new('empty'))).to eq(described_class::EXTRACTION_EMPTY)
    end

    it 'detects NoFeedItemsExtracted through Exception#cause' do
      klass = stub_no_feed_items_extracted
      root = klass.new('empty')
      wrapped = StandardError.new('wrapped')
      outer = StandardError.new('outer')
      allow(outer).to receive(:cause).and_return(wrapped)
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(outer)).to eq(described_class::EXTRACTION_EMPTY)
    end

    it 'ignores attempts payload when mapping HTTP semantics' do
      klass = stub_no_feed_items_extracted_with_attempts
      error = klass.new(attempts: [{ strategy: :faraday, items_count: 0 }])

      expect(described_class.classify(error)).to have_attributes(
        status: 422,
        code: 'EXTRACTION_EMPTY',
        kind: 'input',
        cacheable: true,
        retryable: false,
        next_action: 'correct_input',
        retry_action: 'none',
        message: a_string_including('could not extract feed items')
      )
    end

    it 'returns the blocked-surface decision for BlockedSurfaceDetected' do
      stub_const('Html2rss::RequestService::BlockedSurfaceDetected', Class.new(Html2rss::Error))
      error = Html2rss::RequestService::BlockedSurfaceDetected.new('challenge')

      expect(described_class.classify(error)).to eq(described_class::BLOCKED_SURFACE)
    end

    it 'uses one human sentence for classified user decisions', :aggregate_failures do
      expect(described_class::BLOCKED_SURFACE.message).to eq(
        'This site blocked automated access. Try another URL or site.'
      )
      expect(described_class::SCRAPER_UNAVAILABLE.message).to eq('Feed fetching is temporarily unavailable.')
      expect(described_class::SERVICE_UNAVAILABLE.message).to eq(
        'The server is too busy or the request timed out.'
      )
      expect(described_class::GATEWAY_TIMEOUT.message).to eq('The target website took too long to respond.')
    end

    it 'returns the scraper-unavailable decision for BotasaurusConnectionFailed' do
      stub_const('Html2rss::RequestService::BotasaurusConnectionFailed', Class.new(Html2rss::Error))
      error = Html2rss::RequestService::BotasaurusConnectionFailed.new('connection refused')

      expect(described_class.classify(error)).to eq(described_class::SCRAPER_UNAVAILABLE)
    end

    it 'returns gateway timeout for RequestTimedOut (Botasaurus/Faraday wall-clock)' do
      stub_request_timed_out
      error = Html2rss::RequestService::RequestTimedOut.new('Botasaurus scrape timed out')

      expect(described_class.classify(error)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'returns gateway timeout for RequestTimedOut with timeout_phase work' do
      stub_request_timed_out
      error = Html2rss::RequestService::RequestTimedOut.new('work timed out', timeout_phase: 'work')

      expect(described_class.classify(error)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'returns service unavailable for RequestTimedOut with timeout_phase queue' do
      stub_request_timed_out
      error = Html2rss::RequestService::RequestTimedOut.new('queued too long', timeout_phase: 'queue')

      expect(described_class.classify(error)).to eq(described_class::SERVICE_UNAVAILABLE)
    end

    it 'returns service unavailable for RequestTimedOut with timeout_phase boot' do
      stub_request_timed_out
      error = Html2rss::RequestService::RequestTimedOut.new('browser boot timed out', timeout_phase: 'boot')

      expect(described_class.classify(error)).to eq(described_class::SERVICE_UNAVAILABLE)
    end

    it 'detects RequestTimedOut through Exception#cause' do
      stub_request_timed_out
      root = Html2rss::RequestService::RequestTimedOut.new('timed out')
      wrapped = StandardError.new('wrapped')
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(wrapped)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'maps queue timeout_phase through Exception#cause to service unavailable' do
      stub_request_timed_out
      root = Html2rss::RequestService::RequestTimedOut.new('capacity', timeout_phase: 'queue')
      wrapped = StandardError.new('wrapped')
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(wrapped)).to eq(described_class::SERVICE_UNAVAILABLE)
    end

    it 'keeps gateway timeout when RequestTimedOut omits timeout_phase reader' do
      stub_const('Html2rss::RequestService::RequestTimedOut', Class.new(Html2rss::Error))
      error = Html2rss::RequestService::RequestTimedOut.new('legacy timed out')

      expect(described_class.classify(error)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'returns internal server error decision for unrelated errors' do
      expect(described_class.classify(StandardError.new('boom'))).to eq(described_class::INTERNAL_SERVER_ERROR)
    end

    it 'classifies UnauthorizedError' do
      expect(described_class.classify(Html2rss::Web::UnauthorizedError.new)).to have_attributes(
        status: 401,
        code: 'UNAUTHORIZED',
        kind: 'auth',
        retryable: false,
        next_action: 'enter_token'
      )
    end

    it 'classifies BadRequestError' do
      expect(described_class.classify(Html2rss::Web::BadRequestError.new('Bad format'))).to have_attributes(
        status: 400,
        code: 'BAD_REQUEST',
        message: 'Bad format',
        kind: 'input',
        retryable: false,
        next_action: 'correct_input'
      )
    end

    it 'classifies TooManyRequestsError' do
      expect(described_class.classify(Html2rss::Web::TooManyRequestsError.new)).to have_attributes(
        status: 429,
        code: 'TOO_MANY_REQUESTS',
        kind: 'client',
        retryable: true
      )
    end

    it 'classifies HealthCheckFailedError' do
      expect(described_class.classify(Html2rss::Web::HealthCheckFailedError.new)).to have_attributes(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        kind: 'server',
        retryable: false,
        next_action: 'none'
      )
    end

    it 'classifies timeout errors correctly', :aggregate_failures do
      stub_const('Rack::Timeout::RequestTimeoutException', Class.new(StandardError))
      expect(described_class.classify(Rack::Timeout::RequestTimeoutException.new)).to eq(
        described_class::SERVICE_UNAVAILABLE
      )
      expect(described_class.classify(Net::OpenTimeout.new('timeout'))).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'classifies low-level network errors as internal server error with network kind' do
      expect(described_class.classify(Errno::ECONNREFUSED.new)).to have_attributes(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        kind: 'network',
        retryable: true
      )
    end
  end

  describe 'Diagnostics' do
    let(:diagnostic_error) do
      klass = stub_no_feed_items_extracted_with_attempts
      klass.new(
        attempts: [
          {
            strategy: :faraday,
            items_count: 0,
            transport_meta: {
              'request_id' => 'req-123',
              'render_ms' => 45,
              'strategy_used' => 'faraday',
              'timeout_phase' => 'work'
            }
          }
        ]
      )
    end

    it 'extracts strategy attempts and transport meta when present', :aggregate_failures do
      diagnostics = described_class::Diagnostics.from_error(diagnostic_error)
      expect(diagnostics).to have_attributes(
        request_id: 'req-123', render_ms: 45, strategy_used: 'faraday', timeout_phase: 'work'
      )
      expect(diagnostics.strategy_attempts.size).to eq(1)
      expect(diagnostics.to_h).to include(
        strategy_attempts: diagnostics.strategy_attempts,
        request_id: 'req-123', render_ms: 45, strategy_used: 'faraday', timeout_phase: 'work'
      )
    end

    it 'prefers transport_meta timeout_phase over RequestTimedOut on the chain' do
      stub_request_timed_out
      timed_out = Html2rss::RequestService::RequestTimedOut.new('queued', timeout_phase: 'queue')
      allow(diagnostic_error).to receive(:cause).and_return(timed_out)

      expect(described_class::Diagnostics.from_error(diagnostic_error).timeout_phase).to eq('work')
    end

    it 'falls back to RequestTimedOut#timeout_phase when transport_meta omits it' do
      stub_request_timed_out
      klass = stub_no_feed_items_extracted_with_attempts
      error = klass.new(
        attempts: [{ strategy: :botasaurus, items_count: 0,
                     transport_meta: { 'request_id' => 'req-9', 'error_category' => 'timeout' } }]
      )
      allow(error).to receive(:cause).and_return(
        Html2rss::RequestService::RequestTimedOut.new('capacity', timeout_phase: 'boot')
      )

      expect(described_class::Diagnostics.from_error(error)).to have_attributes(
        request_id: 'req-9', error_category: 'timeout', timeout_phase: 'boot'
      )
    end

    it 'emits timeout_phase from RequestTimedOut when attempts are absent' do
      stub_request_timed_out
      error = Html2rss::RequestService::RequestTimedOut.new('queued too long', timeout_phase: 'queue')

      expect(described_class::Diagnostics.from_error(error).to_h).to eq(timeout_phase: 'queue')
    end

    it 'returns empty diagnostics when no attempts are present' do
      expect(described_class::Diagnostics.from_error(StandardError.new('boom'))).to eq(
        described_class::Diagnostics.empty
      )
    end
  end

  describe '.error_chain' do
    it 'walks causes without looping on cycles' do
      first = StandardError.new('first')
      second = StandardError.new('second')
      allow(first).to receive(:cause).and_return(second)
      allow(second).to receive(:cause).and_return(first)

      expect(described_class.error_chain(first)).to eq([first, second])
    end
  end
end
