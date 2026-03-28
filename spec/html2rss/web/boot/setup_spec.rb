# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Boot::Setup do
  let(:boot_secret_key) { 'secret-key-123456789012345678901234' }
  let(:sentry_dsn) { 'https://example@sentry.invalid/1' }
  let(:boot_env) do
    {
      'RACK_ENV' => 'development',
      'HTML2RSS_SECRET_KEY' => boot_secret_key,
      'BUILD_TAG' => '2026-03-27',
      'GIT_SHA' => 'abc1234',
      'SENTRY_ENABLE_LOGS' => nil
    }
  end

  before do
    allow(Html2rss::Web::Flags).to receive(:validate!)
    allow(Html2rss::Web::Boot::Sentry).to receive(:configure!)
  end

  describe '.call!' do
    it 'validates environment state', :aggregate_failures do
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_environment!)
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_production_security!)

      described_class.call!

      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_environment!).once
      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_production_security!).once
      expect(Html2rss::Web::Flags).to have_received(:validate!).once
    end

    it 'routes rack-timeout logs through the shared app logger' do
      stub_const('Rack::Timeout::Logger', Class.new)
      logger_holder = { value: nil }
      Rack::Timeout::Logger.define_singleton_method(:logger=) { |value| logger_holder[:value] = value }
      Rack::Timeout::Logger.define_singleton_method(:logger) { logger_holder[:value] }

      described_class.call!

      expect(Rack::Timeout::Logger.logger).to be(Html2rss::Web::AppLogger.logger)
    end

    it 'captures and scrubs sensitive env vars after validation', :aggregate_failures do
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_environment!).ordered do
        expect(ENV.fetch('HTML2RSS_SECRET_KEY', nil)).to eq(boot_secret_key)
        expect(ENV.fetch('HEALTH_CHECK_TOKEN', nil)).to eq('health-token')
      end
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_production_security!).ordered do
        expect(ENV.fetch('SENTRY_DSN', nil)).to eq(sentry_dsn)
      end

      ClimateControl.modify(scrubbed_env) do
        described_class.call!

        expect_runtime_env_to_match_boot_values
        expect_sensitive_env_to_be_scrubbed
      end
    end

    it 'configures Sentry for error reporting when a DSN is present', :aggregate_failures do
      stub_environment_validation
      allow(Html2rss::Web::Boot::Sentry).to receive(:configure!).and_call_original
      allow(Html2rss::Web::Boot::Sentry).to receive(:require).with('sentry-ruby').and_return(true)
      allow(Bundler).to receive(:require)
      fake_sentry = build_fake_sentry
      stub_const('Sentry', fake_sentry)

      ClimateControl.modify(boot_env.merge('SENTRY_DSN' => sentry_dsn)) do
        described_class.call!
      end

      expect_sentry_to_be_configured
    end

    it 'enables Sentry logs when SENTRY_ENABLE_LOGS is true', :aggregate_failures do
      stub_environment_validation
      allow(Html2rss::Web::Boot::Sentry).to receive(:configure!).and_call_original
      allow(Html2rss::Web::Boot::Sentry).to receive(:require).with('sentry-ruby').and_return(true)
      allow(Bundler).to receive(:require)
      fake_sentry = build_fake_sentry
      stub_const('Sentry', fake_sentry)

      ClimateControl.modify(boot_env.merge('SENTRY_DSN' => sentry_dsn, 'SENTRY_ENABLE_LOGS' => 'true')) do
        described_class.call!
      end

      expect_sentry_config(:enable_logs, true)
    end

    it 'fails fast when SENTRY_ENABLE_LOGS is malformed' do
      stub_environment_validation
      allow(Html2rss::Web::Boot::Sentry).to receive(:configure!).and_call_original
      allow(Html2rss::Web::Boot::Sentry).to receive(:require).with('sentry-ruby').and_return(true)
      allow(Bundler).to receive(:require)
      fake_sentry = build_fake_sentry
      stub_const('Sentry', fake_sentry)

      expect do
        ClimateControl.modify(boot_env.merge('SENTRY_DSN' => sentry_dsn, 'SENTRY_ENABLE_LOGS' => '1')) do
          described_class.call!
        end
      end.to raise_error(ArgumentError, /SENTRY_ENABLE_LOGS/)
    end

    it 'logs build metadata on startup' do
      stub_environment_validation
      logger = instance_double(Logger, info: nil)
      allow(Html2rss::Web::AppLogger).to receive(:logger).and_return(logger)

      ClimateControl.modify(boot_env) do
        described_class.call!
      end

      expect(logger).to have_received(:info).with(
        a_string_including('"build_tag":"2026-03-27"', '"git_sha":"abc1234"', '"event_name":"app.start"')
      )
    end
  end

  def stub_environment_validation
    allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_environment!)
    allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_production_security!)
  end

  def scrubbed_env
    boot_env.merge(
      'HEALTH_CHECK_TOKEN' => 'health-token',
      'SENTRY_DSN' => sentry_dsn
    )
  end

  def expect_runtime_env_to_match_boot_values
    expect(Html2rss::Web::RuntimeEnv.secret_key).to eq(boot_secret_key)
    expect(Html2rss::Web::RuntimeEnv.health_check_token).to eq('health-token')
    expect(Html2rss::Web::RuntimeEnv.sentry_dsn).to eq(sentry_dsn)
  end

  def expect_sensitive_env_to_be_scrubbed
    expect(ENV.fetch('HTML2RSS_SECRET_KEY', nil)).to be_nil
    expect(ENV.fetch('HEALTH_CHECK_TOKEN', nil)).to be_nil
    expect(ENV.fetch('SENTRY_DSN', nil)).to be_nil
  end

  def expect_sentry_to_be_configured
    expect(Bundler).to have_received(:require).with(:sentry)
    expect_sentry_config(:dsn, sentry_dsn)
    expect_sentry_config(:enable_logs, false)
    expect_sentry_config(:release, '2026-03-27+abc1234')
  end

  def build_fake_sentry
    captured_config = nil
    fake_logger = build_fake_sentry_logger
    config_factory = method(:build_fake_sentry_config)

    Module.new.tap do |fake_sentry|
      define_fake_sentry_accessors(fake_sentry, fake_logger, -> { captured_config })
      define_fake_sentry_init(fake_sentry, config_factory, ->(config) { captured_config = config })
    end
  end

  def define_fake_sentry_accessors(fake_sentry, fake_logger, captured_config)
    fake_sentry.define_singleton_method(:initialized?) { false }
    fake_sentry.define_singleton_method(:logger) { fake_logger }
    fake_sentry.define_singleton_method(:captured_config) { captured_config.call }
  end

  def define_fake_sentry_init(fake_sentry, config_factory, assign_config)
    fake_sentry.define_singleton_method(:init) do |&block|
      config = config_factory.call
      assign_config.call(config)
      block.call(config)
    end
  end

  def expect_sentry_config(attribute, expected_value)
    expect(Sentry.captured_config.public_send(attribute)).to eq(expected_value)
  end

  def build_fake_sentry_logger
    Class.new do
      def info(*) = nil
    end.new
  end

  def build_fake_sentry_config
    Struct.new(:dsn, :environment, :enable_logs, :send_default_pii, :release).new
  end
end
