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

  describe '.classify' do
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

    it 'returns the scraper-unavailable decision for BotasaurusConnectionFailed' do
      stub_const('Html2rss::RequestService::BotasaurusConnectionFailed', Class.new(Html2rss::Error))
      error = Html2rss::RequestService::BotasaurusConnectionFailed.new('connection refused')

      expect(described_class.classify(error)).to eq(described_class::SCRAPER_UNAVAILABLE)
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

  describe '.extract_diagnostics' do
    let(:diagnostic_error) do
      klass = stub_no_feed_items_extracted_with_attempts
      klass.new(
        attempts: [
          {
            strategy: :faraday,
            items_count: 0,
            transport_meta: { 'request_id' => 'req-123', 'render_ms' => 45, 'strategy_used' => 'faraday' }
          }
        ]
      )
    end

    it 'extracts strategy attempts and transport meta when present', :aggregate_failures do
      diagnostics = described_class.extract_diagnostics(diagnostic_error)
      expect(diagnostics[:strategy_attempts].size).to eq(1)
      expect(diagnostics[:request_id]).to eq('req-123')
      expect(diagnostics[:render_ms]).to eq(45)
      expect(diagnostics[:strategy_used]).to eq('faraday')
    end

    it 'returns empty hash when no diagnostics are present' do
      expect(described_class.extract_diagnostics(StandardError.new('boom'))).to eq({})
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
