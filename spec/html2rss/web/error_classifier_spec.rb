# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::ErrorClassifier do
  describe '.classify' do
    it 'returns a carried Decision without remapping' do
      decided = described_class::DecidedError.new(described_class::BLOCKED_SURFACE)

      expect(described_class.classify(decided)).to eq(described_class::BLOCKED_SURFACE)
    end

    it 'carries diagnostics on DecidedError', :aggregate_failures do
      diagnostics = described_class::Diagnostics.from_attempts(
        [{ strategy: :default, items_count: 0, error_class: nil }]
      )
      decided = described_class::DecidedError.new(described_class::BLOCKED_SURFACE, diagnostics:)

      expect(decided.diagnostics).to eq(diagnostics)
      expect(described_class::Diagnostics.from_error(decided)).to eq(diagnostics)
    end

    it 'returns the extraction-empty decision for NoFeedItemsExtracted' do
      expect(described_class.classify(Html2rss::NoFeedItemsExtracted.new(attempts: []))).to eq(
        described_class::EXTRACTION_EMPTY
      )
    end

    it 'keeps listing NoFeedItemsExtracted cacheable EXTRACTION_EMPTY' do
      error = Html2rss::NoFeedItemsExtracted.new(attempts: [], surface_category: :listing)

      expect(described_class.classify(error)).to eq(described_class::EXTRACTION_EMPTY)
    end

    it 'maps blocked_surface NoFeedItemsExtracted to BLOCKED_SURFACE' do
      error = Html2rss::NoFeedItemsExtracted.new(attempts: [], surface_category: :blocked_surface)

      expect(described_class.classify(error)).to eq(described_class::BLOCKED_SURFACE)
    end

    it 'maps app_shell NoFeedItemsExtracted to uncacheable EXTRACTION_EMPTY' do
      error = Html2rss::NoFeedItemsExtracted.new(attempts: [], surface_category: :app_shell)

      expect(described_class.classify(error)).to eq(described_class::EXTRACTION_EMPTY_UNCACHEABLE)
    end

    it 'maps high_entropy_surface NoFeedItemsExtracted to uncacheable EXTRACTION_EMPTY' do
      error = Html2rss::NoFeedItemsExtracted.new(attempts: [], surface_category: :high_entropy_surface)

      expect(described_class.classify(error)).to eq(described_class::EXTRACTION_EMPTY_UNCACHEABLE)
    end

    it 'detects NoFeedItemsExtracted through Exception#cause' do
      root = Html2rss::NoFeedItemsExtracted.new(attempts: [])
      wrapped = StandardError.new('wrapped')
      outer = StandardError.new('outer')
      allow(outer).to receive(:cause).and_return(wrapped)
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(outer)).to eq(described_class::EXTRACTION_EMPTY)
    end

    it 'ignores attempts payload when mapping HTTP semantics' do
      error = Html2rss::NoFeedItemsExtracted.new(attempts: [{ strategy: :default, items_count: 0 }])

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
      error = Html2rss::RequestService::BlockedSurfaceDetected.new('challenge')

      expect(described_class.classify(error)).to eq(described_class::BLOCKED_SURFACE)
    end

    it 'exposes blocked-surface cache policy and empty reason', :aggregate_failures do
      expect(described_class::BLOCKED_SURFACE.cacheable).to be(true)
      expect(described_class::BLOCKED_SURFACE.empty_reason).to eq('blocked_surface')
    end

    it 'classifies ConnectionFailed as internal network error', :aggregate_failures,
       if: Html2rss::RequestService.const_defined?(:ConnectionFailed, false) do
      expect(described_class.classify(Html2rss::RequestService::ConnectionFailed.new('refused'))).to eq(
        described_class::INTERNAL_NETWORK_ERROR
      )
      expect(described_class.classify(Html2rss::RequestService::ConnectionFailed.new('refused'))).to have_attributes(
        status: 500, kind: 'network', cacheable: false
      )
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
      error = Html2rss::RequestService::BotasaurusConnectionFailed.new('connection refused')

      expect(described_class.classify(error)).to eq(described_class::SCRAPER_UNAVAILABLE)
    end

    it 'returns gateway timeout for RequestTimedOut (Botasaurus/HTTPX wall-clock)' do
      error = Html2rss::RequestService::RequestTimedOut.new('Botasaurus scrape timed out')

      expect(described_class.classify(error)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'returns gateway timeout for RequestTimedOut with timeout_phase work' do
      error = Html2rss::RequestService::RequestTimedOut.new('work timed out', timeout_phase: 'work')

      expect(described_class.classify(error)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'returns service unavailable for RequestTimedOut with timeout_phase queue' do
      error = Html2rss::RequestService::RequestTimedOut.new('queued too long', timeout_phase: 'queue')

      expect(described_class.classify(error)).to eq(described_class::SERVICE_UNAVAILABLE)
    end

    it 'returns service unavailable for RequestTimedOut with timeout_phase boot' do
      error = Html2rss::RequestService::RequestTimedOut.new('browser boot timed out', timeout_phase: 'boot')

      expect(described_class.classify(error)).to eq(described_class::SERVICE_UNAVAILABLE)
    end

    it 'detects RequestTimedOut through Exception#cause' do
      root = Html2rss::RequestService::RequestTimedOut.new('timed out')
      wrapped = StandardError.new('wrapped')
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(wrapped)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'maps queue timeout_phase through Exception#cause to service unavailable' do
      root = Html2rss::RequestService::RequestTimedOut.new('capacity', timeout_phase: 'queue')
      wrapped = StandardError.new('wrapped')
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(wrapped)).to eq(described_class::SERVICE_UNAVAILABLE)
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

    {
      Html2rss::InvalidOption => 'limit must be an Integer in 1..100, got 0',
      Html2rss::Url::InvalidUrlError => 'URL must be absolute'
    }.each do |error_class, message|
      it "passes the #{error_class} message through as a 400 client error", :aggregate_failures do
        expect(described_class.classify(error_class.new(message))).to have_attributes(
          status: 400, code: 'BAD_REQUEST', message:, kind: 'input', cacheable: false, retryable: false
        )
      end
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
      expect(described_class.classify(Async::TimeoutError.new)).to eq(described_class::GATEWAY_TIMEOUT)
      expect(described_class.classify(Net::OpenTimeout.new('timeout'))).to eq(described_class::GATEWAY_TIMEOUT)
      expect(described_class.classify(HTTPX::TimeoutError.new(5, 'timeout'))).to eq(
        described_class::GATEWAY_TIMEOUT
      )
    end

    it 'returns the forbidden decision for PrivateNetworkDenied' do
      error = Html2rss::RequestService::PrivateNetworkDenied.new('private network blocked')

      expect(described_class.classify(error)).to eq(described_class::PRIVATE_NETWORK_DENIED)
    end

    it 'classifies low-level network errors as internal server error with network kind' do
      expect(described_class.classify(Errno::ECONNREFUSED.new)).to have_attributes(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        kind: 'network',
        retryable: true
      )
    end

    it 'classifies HTTPX network errors as internal server error with network kind', :aggregate_failures do
      expect(described_class.classify(HTTPX::ConnectionError.new('conn reset'))).to have_attributes(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        kind: 'network',
        retryable: true
      )
      expect(described_class.classify(HTTPX::TLSError.new('tls error'))).to have_attributes(
        status: 500,
        code: 'INTERNAL_SERVER_ERROR',
        kind: 'network',
        retryable: true
      )
    end
  end

  describe 'Diagnostics' do
    let(:diagnostic_error) do
      Html2rss::NoFeedItemsExtracted.new(
        attempts: [
          {
            strategy: :default,
            items_count: 0,
            transport_meta: {
              'request_id' => 'req-123',
              'render_ms' => 45,
              'strategy_used' => 'default',
              'timeout_phase' => 'work'
            }
          }
        ]
      )
    end

    it 'extracts strategy attempts and transport meta when present', :aggregate_failures do
      diagnostics = described_class::Diagnostics.from_error(diagnostic_error)
      expect(diagnostics).to have_attributes(
        request_id: 'req-123', render_ms: 45, strategy_used: 'default', timeout_phase: 'work'
      )
      expect(diagnostics.strategy_attempts.size).to eq(1)
      expect(diagnostics.to_h).to include(
        strategy_attempts: diagnostics.strategy_attempts,
        request_id: 'req-123', render_ms: 45, strategy_used: 'default', timeout_phase: 'work'
      )
    end

    it 'copies surface_category from NoFeedItemsExtracted on the chain' do
      error = Html2rss::NoFeedItemsExtracted.new(
        attempts: [{ strategy: :default, items_count: 0 }],
        surface_category: :app_shell
      )

      expect(described_class::Diagnostics.from_error(error).to_h).to include(
        surface_category: :app_shell,
        strategy_attempts: [{ strategy: :default, items_count: 0 }]
      )
    end

    it 'prefers transport_meta timeout_phase over RequestTimedOut on the chain' do
      timed_out = Html2rss::RequestService::RequestTimedOut.new('queued', timeout_phase: 'queue')
      allow(diagnostic_error).to receive(:cause).and_return(timed_out)

      expect(described_class::Diagnostics.from_error(diagnostic_error).timeout_phase).to eq('work')
    end

    it 'falls back to RequestTimedOut#timeout_phase when transport_meta omits it' do
      error = Html2rss::NoFeedItemsExtracted.new(
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
      error = Html2rss::RequestService::RequestTimedOut.new('queued too long', timeout_phase: 'queue')

      expect(described_class::Diagnostics.from_error(error).to_h).to eq(timeout_phase: 'queue')
    end

    it 'returns empty diagnostics when no attempts are present' do
      expect(described_class::Diagnostics.from_error(StandardError.new('boom'))).to eq(
        described_class::Diagnostics.empty
      )
    end

    it 'prefers non-empty DecidedError diagnostics over chain digging' do
      carried = described_class::Diagnostics.from_attempts(
        [{ strategy: :botasaurus, items_count: 0, error_class: 'Timeout::Error' }]
      )
      decided = described_class::DecidedError.new(described_class::EXTRACTION_EMPTY, diagnostics: carried)

      expect(described_class::Diagnostics.from_error(decided)).to eq(carried)
    end

    it 'extracts attempts from RequestTimedOut on the chain', :aggregate_failures do
      attempts = [{ strategy: :default, error_class: 'Html2rss::RequestService::RequestTimedOut', elapsed_ms: 12 }]
      error = Html2rss::RequestService::RequestTimedOut.new('timed out', timeout_phase: 'work')
      error.attempts = attempts

      diagnostics = described_class::Diagnostics.from_error(error)
      expect(diagnostics.strategy_attempts).to eq(attempts)
      expect(diagnostics.timeout_phase).to eq('work')
    end

    it 'extracts attempts from BlockedSurfaceDetected on the chain', :aggregate_failures do
      attempts = [{ strategy: :botasaurus, error_class: 'Html2rss::RequestService::BlockedSurfaceDetected' }]
      error = Html2rss::RequestService::BlockedSurfaceDetected.new('challenge')
      error.attempts = attempts

      expect(described_class::Diagnostics.from_error(error).strategy_attempts).to eq(attempts)
    end

    it 'extracts attempts from ConnectionFailed on the chain', :aggregate_failures,
       if: Html2rss::RequestService.const_defined?(:ConnectionFailed, false) do
      attempts = [{ strategy: :default, error_class: 'Html2rss::RequestService::ConnectionFailed' }]
      error = Html2rss::RequestService::ConnectionFailed.new('refused')
      error.attempts = attempts

      expect(described_class::Diagnostics.from_error(error).strategy_attempts).to eq(attempts)
    end

    it 'extracts transport_meta without attempts from Html2rss::Error on the chain', :aggregate_failures do
      error = Html2rss::RequestService::RequestTimedOut.new('queued', timeout_phase: 'queue')
      error.transport_meta = { request_id: 'req-direct', render_ms: 99, strategy_used: 'botasaurus' }

      expect(described_class::Diagnostics.from_error(error)).to have_attributes(
        request_id: 'req-direct', render_ms: 99, strategy_used: 'botasaurus', timeout_phase: 'queue'
      )
      expect(described_class::Diagnostics.from_error(error).strategy_attempts).to eq([])
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

  describe '.classify (HTTP errors)' do
    def decision(error) = described_class.classify(error)

    it 'maps 401 to an auth decision', :aggregate_failures do
      expect(decision(Html2rss::Web::UnauthorizedError.new('nope'))).to have_attributes(
        status: 401, code: 'UNAUTHORIZED', message: 'nope', kind: 'auth', cacheable: false,
        retryable: false, next_action: 'enter_token', retry_action: 'none'
      )
    end

    it 'maps 429 to a retryable client decision with a default message', :aggregate_failures do
      expect(decision(Html2rss::Web::TooManyRequestsError.new)).to have_attributes(
        status: 429, kind: 'client', retryable: true, next_action: 'retry', retry_action: 'primary',
        message: Html2rss::Web::TooManyRequestsError::DEFAULT_MESSAGE
      )
      blank = Html2rss::Web::TooManyRequestsError.new(Html2rss::Web::TooManyRequestsError.name)
      expect(decision(blank).message).to eq('Too many requests. Wait before retrying.')
    end

    it 'maps 400 and 403 to input decisions', :aggregate_failures do
      [[Html2rss::Web::BadRequestError, 400], [Html2rss::Web::ForbiddenError, 403]].each do |klass, status|
        expect(decision(klass.new('msg'))).to have_attributes(
          status:, kind: 'input', retryable: false, next_action: 'correct_input', retry_action: 'none', message: 'msg'
        )
      end
    end

    it 'maps health check failures to a non-retryable server decision' do
      expect(decision(Html2rss::Web::HealthCheckFailedError.new)).to have_attributes(
        kind: 'server', retryable: false, next_action: 'none', retry_action: 'none'
      )
    end

    it 'maps other HTTP errors to retryable server decisions', :aggregate_failures do
      expect(decision(Html2rss::Web::InternalServerError.new('oops'))).to have_attributes(
        status: 500, kind: 'server', retryable: true, next_action: 'retry', retry_action: 'primary', message: 'oops'
      )
    end

    it 'falls back to the class default message when the message is blank or the class name', :aggregate_failures do
      klass = Html2rss::Web::BadRequestError
      expect(decision(klass.new).message).to eq(klass::DEFAULT_MESSAGE)
      expect(decision(klass.new('')).message).to eq(klass::DEFAULT_MESSAGE)
      expect(decision(klass.new(klass.name)).message).to eq(klass::DEFAULT_MESSAGE)
    end

    it 'never caches classified HTTP errors' do
      expect(decision(Html2rss::Web::BadRequestError.new('x')).cacheable).to be(false)
    end
  end

  describe '.classify (transport and validation)' do
    def decision(error) = described_class.classify(error)

    it 'maps invalid caller input from the gem to a 400 with the gem message', :aggregate_failures do
      expect(decision(Html2rss::InvalidOption.new('bad option'))).to have_attributes(
        status: 400, code: 'BAD_REQUEST', message: 'bad option', cacheable: false, kind: 'input'
      )
      expect(decision(Html2rss::Url::InvalidUrlError.new('bad url'))).to have_attributes(status: 400,
                                                                                         message: 'bad url')
    end

    it 'maps private network denial to a cacheable 403', :aggregate_failures do
      expect(decision(Html2rss::RequestService::PrivateNetworkDenied.new('x'))).to eq(
        described_class::PRIVATE_NETWORK_DENIED
      )
      expect(described_class::PRIVATE_NETWORK_DENIED).to have_attributes(status: 403, cacheable: true)
    end

    it 'maps plain timeouts to GATEWAY_TIMEOUT', :aggregate_failures do
      [Timeout::Error.new, Errno::ETIMEDOUT.new, Async::TimeoutError.new,
       HTTPX::TimeoutError.new(1, 'x')].each do |error|
        expect(decision(error)).to eq(described_class::GATEWAY_TIMEOUT)
      end
    end

    it 'finds timeouts through the cause chain' do
      outer = begin
        begin
          raise Timeout::Error, 'inner'
        rescue Timeout::Error
          raise StandardError, 'outer'
        end
      rescue StandardError => error
        error
      end

      expect(decision(outer)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'maps queue and boot request timeouts to SERVICE_UNAVAILABLE and others to GATEWAY_TIMEOUT',
       :aggregate_failures do
      %w[queue boot].each do |phase|
        error = Html2rss::RequestService::RequestTimedOut.new('t', timeout_phase: phase)
        expect(decision(error)).to eq(described_class::SERVICE_UNAVAILABLE)
      end
      other = Html2rss::RequestService::RequestTimedOut.new('t', timeout_phase: 'read')
      expect(decision(other)).to eq(described_class::GATEWAY_TIMEOUT)
    end

    it 'classifies network failures as internal network errors', :aggregate_failures do
      [SocketError.new, EOFError.new, Errno::ECONNREFUSED.new, Errno::EHOSTUNREACH.new].each do |error|
        expect(decision(error)).to eq(described_class::INTERNAL_NETWORK_ERROR)
      end
    end

    it 'classifies unknown errors as internal server errors', :aggregate_failures do
      expect(decision(StandardError.new('x'))).to eq(described_class::INTERNAL_SERVER_ERROR)
      expect(described_class::INTERNAL_SERVER_ERROR).to have_attributes(status: 500, kind: 'server', cacheable: false)
    end

    it 'treats wrapped network errors as network failures' do
      wrapped = begin
        begin
          raise SocketError, 'dns'
        rescue SocketError
          raise StandardError, 'wrapper'
        end
      rescue StandardError => error
        error
      end

      expect(decision(wrapped)).to eq(described_class::INTERNAL_NETWORK_ERROR)
    end
  end

  describe '.error_chain (ordering and cycles)' do
    it 'walks causes in order and stops on cycles', :aggregate_failures do
      inner = StandardError.new('inner')
      outer = StandardError.new('outer')
      allow(outer).to receive(:cause).and_return(inner)
      allow(inner).to receive(:cause).and_return(outer)

      expect(described_class.error_chain(outer)).to eq([outer, inner])
      expect(described_class.error_chain(nil)).to eq([])
    end
  end

  describe described_class::Decision do
    it 'maps decision codes to empty reasons', :aggregate_failures do
      mapping = {
        'BLOCKED_SURFACE' => 'blocked_surface', 'FORBIDDEN' => 'forbidden',
        'BAD_REQUEST' => 'invalid_input', 'EXTRACTION_EMPTY' => 'content_extraction_empty'
      }
      mapping.each do |code, reason|
        expect(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY.with(code:).empty_reason).to eq(reason)
      end
    end
  end

  describe described_class::Diagnostics do
    it 'is empty without attempts', :aggregate_failures do
      expect(described_class.from_attempts(nil)).to equal(described_class.empty)
      expect(described_class.from_attempts([])).to equal(described_class.empty)
      expect(described_class.from_error(StandardError.new('x'))).to equal(described_class.empty)
    end

    it 'expands the last transport meta (symbol or string keys)', :aggregate_failures do
      attempts = [{ transport_meta: { request_id: 'old' } },
                  { 'transport_meta' => { 'request_id' => 'r1', 'strategy_used' => 'default', render_ms: 12,
                                          error_category: 'dns', timeout_phase: 'read' } }]
      diagnostics = described_class.from_attempts(attempts)

      expect(diagnostics).to have_attributes(
        strategy_attempts: attempts, request_id: 'r1', strategy_used: 'default', render_ms: 12,
        error_category: 'dns', timeout_phase: 'read', surface_category: nil
      )
    end

    it 'omits blank fields from the sparse hash', :aggregate_failures do
      diagnostics = described_class.from_attempts([{ transport_meta: { request_id: 'r' } }])

      expect(diagnostics.to_h).to eq(strategy_attempts: [{ transport_meta: { request_id: 'r' } }], request_id: 'r')
      expect(described_class.empty.to_h).to eq({})
    end

    it 'digs the surface category from NoFeedItemsExtracted in the chain' do
      error = Html2rss::NoFeedItemsExtracted.new(attempts: [], surface_category: :app_shell)

      expect(described_class.from_error(error).surface_category).to eq(:app_shell)
    end

    it 'prefers carried DecidedError diagnostics when non-empty', :aggregate_failures do
      carried = described_class.from_attempts([{ transport_meta: { request_id: 'carried' } }])
      decided = Html2rss::Web::ErrorClassifier::DecidedError.new(Html2rss::Web::ErrorClassifier::BLOCKED_SURFACE,
                                                                 diagnostics: carried)

      expect(described_class.from_error(decided)).to equal(carried)
      empty = Html2rss::Web::ErrorClassifier::DecidedError.new(Html2rss::Web::ErrorClassifier::BLOCKED_SURFACE)
      expect(described_class.from_error(empty)).to equal(described_class.empty)
    end

    it 'takes the timeout phase from a RequestTimedOut in the chain' do
      error = Html2rss::RequestService::RequestTimedOut.new('t', timeout_phase: 'queue')

      expect(described_class.from_error(error).timeout_phase).to eq('queue')
    end
  end
end
