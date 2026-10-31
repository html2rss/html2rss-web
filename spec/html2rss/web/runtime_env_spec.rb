# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

RSpec.describe Html2rss::Web::RuntimeEnv do
  after { described_class.reset! }

  describe '.admin_access_token' do
    it 'returns the configured access token when present' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'admin-token') do
        expect(described_class.admin_access_token).to eq('admin-token')
      end
    end

    it 'falls back to the quickstart placeholder when the access token is blank' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => '   ') do
        expect(described_class.admin_access_token).to eq('CHANGE_ME_ADMIN_TOKEN')
      end
    end
  end

  describe '.health_check_token' do
    it 'returns the configured health-check token when present' do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => 'health-token') do
        expect(described_class.health_check_token).to eq('health-token')
      end
    end

    it 'returns nil when the health-check token is blank' do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => '   ') do
        expect(described_class.health_check_token).to be_nil
      end
    end

    it 'returns nil when the health-check token is unset' do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => nil) do
        expect(described_class.health_check_token).to be_nil
      end
    end

    it 'returns the placeholder only when that literal is configured' do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => 'CHANGE_ME_HEALTH_CHECK_TOKEN') do
        expect(described_class.health_check_token).to eq('CHANGE_ME_HEALTH_CHECK_TOKEN')
      end
    end

    it 'rejects a blank token and the placeholder for private probes' do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => '   ') do
        expect(described_class.private_probe_token).to be_nil
      end
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => 'CHANGE_ME_HEALTH_CHECK_TOKEN') do
        expect(described_class.private_probe_token).to be_nil
      end
    end
  end

  def with_env(overrides, &) = ClimateControl.modify(overrides, &)

  describe 'typed readers' do
    it 'reads the secret key and raises when it is missing', :aggregate_failures do
      with_env('HTML2RSS_SECRET_KEY' => 'shh') { expect(described_class.secret_key).to eq('shh') }
      with_env('HTML2RSS_SECRET_KEY' => nil) do
        expect { described_class.secret_key }.to raise_error(KeyError, 'key not found: HTML2RSS_SECRET_KEY')
      end
    end

    it 'strips the health check token', :aggregate_failures do
      with_env('HEALTH_CHECK_TOKEN' => '  tok  ') do
        expect(described_class.health_check_token).to eq('tok')
        expect(described_class.private_probe_token).to eq('tok')
      end
    end

    it 'returns the raw access token (empty when unset)', :aggregate_failures do
      with_env('HTML2RSS_ACCESS_TOKEN' => ' raw ') { expect(described_class.access_token).to eq(' raw ') }
      with_env('HTML2RSS_ACCESS_TOKEN' => nil) { expect(described_class.access_token).to eq('') }
    end

    it 'strips the admin access token' do
      with_env('HTML2RSS_ACCESS_TOKEN' => '  admin  ') { expect(described_class.admin_access_token).to eq('admin') }
    end

    it 'reports sentry state from a non-blank DSN', :aggregate_failures do
      with_env('SENTRY_DSN' => 'https://k@sentry.example/1') do
        expect(described_class.sentry_dsn).to eq('https://k@sentry.example/1')
        expect(described_class.sentry_enabled?).to be(true)
      end
      with_env('SENTRY_DSN' => '  ') { expect(described_class.sentry_enabled?).to be(false) }
      with_env('SENTRY_DSN' => nil) do
        expect(described_class.sentry_dsn).to be_nil
        expect(described_class.sentry_enabled?).to be(false)
      end
    end

    it 'defaults build metadata', :aggregate_failures do
      with_env('BUILD_TAG' => nil, 'GIT_SHA' => nil) do
        expect(described_class.build_tag).to eq('unknown')
        expect(described_class.git_sha).to eq('unknown')
      end
      with_env('BUILD_TAG' => 'v1', 'GIT_SHA' => 'abc') do
        expect(described_class.build_tag).to eq('v1')
        expect(described_class.git_sha).to eq('abc')
      end
    end

    it 'reads RACK_ENV from the environment, defaulting to development', :aggregate_failures do
      with_env('RACK_ENV' => 'production') { expect(described_class.rack_env).to eq('production') }
      with_env('RACK_ENV' => nil) { expect(described_class.rack_env).to eq('development') }
    end

    it 'parses numeric settings with defaults', :aggregate_failures do
      with_env('PORT' => '8080', 'WEB_CONCURRENCY' => '4', 'REQUEST_TIMEOUT_SECONDS' => '12.5') do
        expect(described_class.port).to eq(8080)
        expect(described_class.web_concurrency).to eq(4)
        expect(described_class.request_timeout_seconds).to eq(12.5)
      end
      with_env('PORT' => nil, 'WEB_CONCURRENCY' => nil, 'REQUEST_TIMEOUT_SECONDS' => nil) do
        expect(described_class.port).to eq(4000)
        expect(described_class.web_concurrency).to eq(2)
        expect(described_class.request_timeout_seconds).to eq(55.0)
      end
    end
  end

  describe '.capture!' do
    let(:env) do
      { 'RACK_ENV' => 'production', 'HTML2RSS_SECRET_KEY' => 's', 'HTML2RSS_ACCESS_TOKEN' => 'a',
        'HEALTH_CHECK_TOKEN' => 'h', 'SENTRY_DSN' => 'd', 'BUILD_TAG' => 'v9', 'PORT' => '1234' }
    end

    it 'returns nil, scrubs sensitive keys from ENV and keeps serving captured values', :aggregate_failures do
      with_env(env) do
        expect(described_class.capture!).to be_nil
        %w[HTML2RSS_SECRET_KEY HTML2RSS_ACCESS_TOKEN HEALTH_CHECK_TOKEN SENTRY_DSN].each do |key|
          expect(ENV).not_to have_key(key)
        end
        expect(ENV.fetch('BUILD_TAG', nil)).to eq('v9')
        expect(described_class.secret_key).to eq('s')
        expect(described_class.access_token).to eq('a')
        expect(described_class.health_check_token).to eq('h')
        expect(described_class.sentry_dsn).to eq('d')
      end
    end

    it 'keeps boot metadata available after ENV changes', :aggregate_failures do
      with_env(env) { described_class.capture! }
      with_env('BUILD_TAG' => nil, 'PORT' => nil) do
        expect(described_class.build_tag).to eq('v9')
        expect(described_class.port).to eq(1234)
      end
    end

    it 'does not scrub ENV in the test environment', :aggregate_failures do
      with_env(env.merge('RACK_ENV' => 'test')) do
        described_class.capture!
        expect(ENV.fetch('HTML2RSS_SECRET_KEY', nil)).to eq('s')
      end
    end

    it 'prefers live ENV values over captured ones' do
      with_env(env) { described_class.capture! }
      with_env('HTML2RSS_SECRET_KEY' => 'live') { expect(described_class.secret_key).to eq('live') }
    end

    it 'does not capture untracked variables' do
      with_env(env.merge('UNTRACKED_VAR' => 'x')) { described_class.capture! }

      expect(described_class.instance_variable_get(:@values).keys).not_to include('UNTRACKED_VAR')
    end
  end

  describe '.reset!' do
    it 'forgets captured values', :aggregate_failures do
      with_env('RACK_ENV' => 'production', 'HTML2RSS_SECRET_KEY' => 's') { described_class.capture! }
      expect(described_class.secret_key).to eq('s')

      described_class.reset!
      with_env('HTML2RSS_SECRET_KEY' => nil) do
        expect { described_class.secret_key }.to raise_error(KeyError)
      end
    end
  end
end
