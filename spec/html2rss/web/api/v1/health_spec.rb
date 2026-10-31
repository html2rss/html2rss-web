# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'
require 'climate_control'

RSpec.describe Html2rss::Web::Api::V1::Health do
  let(:probe_token) { 'probe-token-0123456789' }
  let(:bearer) { "Bearer #{probe_token}" }
  let(:now) { Time.utc(2026, 1, 2, 3, 4, 5) }

  def request_with(header = nil)
    env = Rack::MockRequest.env_for('/api/v1/health')
    env['HTTP_AUTHORIZATION'] = header if header
    Rack::Request.new(env)
  end

  before do
    allow(Html2rss::Web::RuntimeEnv).to receive(:private_probe_token).and_return(probe_token)
    allow(Html2rss::Web::LocalConfig).to receive(:load_snapshot)
    allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)
    allow(Time).to receive(:now).and_return(now)
  end

  describe '.show' do
    it 'returns the health payload for the configured probe token', :aggregate_failures do
      health = described_class.show(request_with(bearer)).dig(:data, :health)

      expect(health).to include(status: 'healthy', timestamp: now.iso8601, checks: {})
      expect(health[:uptime]).to be_a(Float)
      expect(Html2rss::Web::LocalConfig).to have_received(:load_snapshot)
    end

    it 'reports the rack environment, defaulting to development', :aggregate_failures do
      ClimateControl.modify('RACK_ENV' => 'production') do
        expect(described_class.show(request_with(bearer)).dig(:data, :health, :environment)).to eq('production')
      end
      ClimateControl.modify('RACK_ENV' => nil) do
        expect(described_class.show(request_with(bearer)).dig(:data, :health, :environment)).to eq('development')
      end
    end

    it 'does not consult account auth when the bearer token matches' do
      described_class.show(request_with(bearer))

      expect(Html2rss::Web::Auth).not_to have_received(:authenticate)
    end

    it 'accepts the health-check account whose token is the probe token' do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return({ username: 'health-check', token: probe_token })

      expect { described_class.show(request_with('Bearer other-token')) }.not_to raise_error
    end

    it 'rejects other accounts, even with the probe token', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return({ username: 'admin', token: probe_token })

      expect { described_class.show(request_with('Bearer other-token')) }
        .to raise_error(Html2rss::Web::UnauthorizedError, 'Health check authentication required')
    end

    it 'rejects a health-check account whose token is not the probe token' do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return({ username: 'health-check', token: 'nope' })

      expect { described_class.show(request_with('Bearer other-token')) }
        .to raise_error(Html2rss::Web::UnauthorizedError)
    end

    it 'rejects missing, wrong and differently sized tokens', :aggregate_failures do
      [nil, 'Bearer wrong-token-0123456789xx', "Bearer #{probe_token[0..-2]}", "Bearer #{probe_token}x",
       "Bearer #{probe_token[0..-2]}X"].each do |header|
        expect { described_class.show(request_with(header)) }
          .to raise_error(Html2rss::Web::UnauthorizedError, 'Health check authentication required')
      end
    end

    it 'rejects everything when no probe token is configured', :aggregate_failures do
      allow(Html2rss::Web::RuntimeEnv).to receive(:private_probe_token).and_return(nil)
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return({ username: 'health-check', token: nil })

      expect { described_class.show(request_with(bearer)) }.to raise_error(Html2rss::Web::UnauthorizedError)
    end

    it 'does not load config before authorization succeeds' do
      expect { described_class.show(request_with) }.to raise_error(Html2rss::Web::UnauthorizedError)
      expect(Html2rss::Web::LocalConfig).not_to have_received(:load_snapshot)
    end

    it 'maps configuration failures to HealthCheckFailedError' do
      allow(Html2rss::Web::LocalConfig).to receive(:load_snapshot).and_raise(StandardError, 'bad yaml')

      expect { described_class.show(request_with(bearer)) }.to raise_error(Html2rss::Web::HealthCheckFailedError)
    end
  end

  describe '.ready' do
    it 'verifies configuration without authentication', :aggregate_failures do
      expect(described_class.ready(nil).dig(:data, :health, :status)).to eq('healthy')
      expect(Html2rss::Web::LocalConfig).to have_received(:load_snapshot)
    end

    it 'fails when configuration cannot be loaded' do
      allow(Html2rss::Web::LocalConfig).to receive(:load_snapshot).and_raise(StandardError)

      expect { described_class.ready(nil) }.to raise_error(Html2rss::Web::HealthCheckFailedError)
    end
  end

  describe '.live' do
    it 'reports alive with a timestamp and never touches configuration', :aggregate_failures do
      expect(described_class.live(nil).dig(:data, :health)).to eq(status: 'alive', timestamp: now.iso8601)
      expect(Html2rss::Web::LocalConfig).not_to have_received(:load_snapshot)
    end
  end
end
