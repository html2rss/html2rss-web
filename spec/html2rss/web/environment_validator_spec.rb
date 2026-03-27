# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app/web/config/environment_validator'
require_relative '../../../app/web/config/flags'
require_relative '../../../app/web/security/account_manager'
require_relative '../../../app/web/security/security_logger'

RSpec.describe Html2rss::Web::EnvironmentValidator do
  def stub_validation_logging
    allow(Html2rss::Web::SecurityLogger).to receive(:log_config_validation_failure)
    allow(Kernel).to receive(:warn)
  end

  describe '.validate_environment!' do
    it 'sets a development default secret key without exiting' do
      stub_validation_logging

      ClimateControl.modify('RACK_ENV' => 'development', 'HTML2RSS_SECRET_KEY' => nil) do
        described_class.validate_environment!
        expect(ENV.fetch('HTML2RSS_SECRET_KEY')).to eq('development-default-key-not-for-production')
      end
    end

    it 'logs development default secret key warnings' do
      stub_validation_logging

      ClimateControl.modify('RACK_ENV' => 'development', 'HTML2RSS_SECRET_KEY' => nil) do
        described_class.validate_environment!
      end

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_config_validation_failure)
        .with('secret_key', 'Using development default secret key', severity: :warn)
    end

    it 'logs missing production secret key failures before exiting' do
      stub_validation_logging

      ClimateControl.modify('RACK_ENV' => 'production', 'HTML2RSS_SECRET_KEY' => nil) do
        expect { described_class.validate_environment! }.to raise_error(SystemExit)
      end

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_config_validation_failure)
        .with('secret_key', 'Missing required secret key')
    end
  end

  describe '.validate_production_security!' do
    it 'logs weak production secret keys before exiting' do
      stub_validation_logging

      ClimateControl.modify(
        'RACK_ENV' => 'production',
        'HTML2RSS_SECRET_KEY' => 'short-secret',
        'BUILD_TAG' => '2026-03-27',
        'GIT_SHA' => 'abc1234'
      ) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_config_validation_failure)
        .with('secret_key', 'Invalid or weak secret key')
    end

    it 'logs missing build metadata before exiting' do
      stub_validation_logging
      allow(Html2rss::Web::AccountManager).to receive(:accounts).and_return([])

      ClimateControl.modify(
        'RACK_ENV' => 'production',
        'HTML2RSS_SECRET_KEY' => '0123456789abcdef0123456789abcdef',
        'BUILD_TAG' => nil,
        'GIT_SHA' => nil
      ) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_config_validation_failure)
        .with('build_metadata', 'Missing BUILD_TAG or GIT_SHA')
    end
  end

  describe '.auto_source_enabled?' do
    context 'when in development' do
      it 'defaults to enabled when flag is not set' do
        ClimateControl.modify('RACK_ENV' => 'development', 'AUTO_SOURCE_ENABLED' => nil) do
          expect(described_class.auto_source_enabled?).to be(true)
        end
      end

      it 'can be disabled explicitly with false' do
        ClimateControl.modify('RACK_ENV' => 'development', 'AUTO_SOURCE_ENABLED' => 'false') do
          expect(described_class.auto_source_enabled?).to be(false)
        end
      end
    end

    context 'when outside development' do
      it 'defaults to disabled when flag is not set' do
        ClimateControl.modify('RACK_ENV' => 'production', 'AUTO_SOURCE_ENABLED' => nil) do
          expect(described_class.auto_source_enabled?).to be(false)
        end
      end

      it 'enables only with explicit true' do
        ClimateControl.modify('RACK_ENV' => 'production', 'AUTO_SOURCE_ENABLED' => 'true') do
          expect(described_class.auto_source_enabled?).to be(true)
        end
      end
    end
  end
end
