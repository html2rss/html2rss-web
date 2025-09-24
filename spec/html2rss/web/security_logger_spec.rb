# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/security_logger'

RSpec.describe Html2rss::Web::SecurityLogger do
  let(:mock_logger) { instance_double(Logger) }

  before do
    allow(Logger).to receive(:new).with($stdout).and_return(mock_logger)
    allow(mock_logger).to receive(:formatter=)
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:warn)
    allow(mock_logger).to receive(:error)
    allow(Kernel).to receive(:warn)
    described_class.reset_logger!
  end

  describe '.log_auth_failure' do
    it 'logs authentication failure with structured data' do
      described_class.log_auth_failure('192.168.1.1', 'Mozilla/5.0', 'invalid_token')

      expect(mock_logger).to have_received(:warn) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data.include?(
          security_event: 'auth_failure',
          ip: '192.168.1.1',
          user_agent: 'Mozilla/5.0',
          reason: 'invalid_token'
        )
      end
    end
  end

  describe '.log_rate_limit_exceeded' do
    it 'logs rate limit exceeded with structured data' do
      described_class.log_rate_limit_exceeded('192.168.1.1', '/api/feeds', 100)

      expect(mock_logger).to have_received(:warn) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data.include?(
          security_event: 'rate_limit_exceeded',
          ip: '192.168.1.1',
          endpoint: '/api/feeds',
          limit: 100
        )
      end
    end
  end

  describe '.log_token_usage' do
    it 'logs token usage with basic data' do
      described_class.log_token_usage('test-token-123', 'https://example.com', true)

      expect(mock_logger).to have_received(:info) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data.include?(
          security_event: 'token_usage',
          success: true,
          url: 'https://example.com'
        )
      end
    end

    it 'includes hashed token in log data' do
      described_class.log_token_usage('test-token-123', 'https://example.com', true)

      expect(mock_logger).to have_received(:info) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data[:token_hash].match?(/\A[a-f0-9]{8}\z/)
      end
    end
  end

  describe '.log_suspicious_activity' do
    it 'logs suspicious activity with details' do
      described_class.log_suspicious_activity('192.168.1.1', 'multiple_failed_attempts', { additional_info: 'test' })

      expect(mock_logger).to have_received(:warn) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data.include?(
          security_event: 'suspicious_activity',
          ip: '192.168.1.1',
          activity: 'multiple_failed_attempts',
          additional_info: 'test'
        )
      end
    end
  end

  describe '.log_blocked_request' do
    it 'logs blocked request with reason' do
      described_class.log_blocked_request('192.168.1.1', 'suspicious_user_agent', '/api/feeds')

      expect(mock_logger).to have_received(:warn) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data.include?(
          security_event: 'blocked_request',
          ip: '192.168.1.1',
          reason: 'suspicious_user_agent',
          endpoint: '/api/feeds'
        )
      end
    end
  end

  describe '.log_config_validation_failure' do
    it 'logs configuration validation failure' do
      described_class.log_config_validation_failure('secret_key', 'Invalid secret key')

      expect(mock_logger).to have_received(:error) do |message|
        data = JSON.parse(message, symbolize_names: true)
        data.include?(
          security_event: 'config_validation_failure',
          component: 'secret_key',
          details: 'Invalid secret key'
        )
      end
    end
  end

  describe 'error handling' do
    it 'does not raise error when logger fails' do
      # Mock the logger to raise an error when warn is called
      allow(mock_logger).to receive(:warn).and_raise(StandardError, 'Logger error')

      # Should not raise an error
      expect { described_class.log_auth_failure('192.168.1.1', 'Mozilla/5.0', 'invalid_token') }.not_to raise_error
    end

    it 'logs error when logger fails' do
      allow(mock_logger).to receive(:warn).and_raise(StandardError, 'Logger error')

      described_class.log_auth_failure('192.168.1.1', 'Mozilla/5.0', 'invalid_token')

      expect(Kernel).to have_received(:warn).with('Security logging error: Logger error')
    end

    it 'logs fallback message when logger fails' do
      allow(mock_logger).to receive(:warn).and_raise(StandardError, 'Logger error')

      described_class.log_auth_failure('192.168.1.1', 'Mozilla/5.0', 'invalid_token')

      expect(Kernel).to have_received(:warn).with(a_string_including('Security event: auth_failure'))
    end
  end
end
