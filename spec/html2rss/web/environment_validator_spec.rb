# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app/web/config/environment_validator'
require_relative '../../../app/web/config/flags'
require_relative '../../../app/web/security/account_manager'
require_relative '../../../app/web/telemetry/observability'

RSpec.describe Html2rss::Web::EnvironmentValidator do
  def stub_validation_logging
    allow(Html2rss::Web::Observability).to receive(:emit)
    allow(Kernel).to receive(:warn)
  end

  def expect_config_validation(component, details, level: :error)
    expect(Html2rss::Web::Observability).to have_received(:emit).with(
      event_name: 'config.validation',
      outcome: 'failure',
      details: { component:, details: },
      level:
    )
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

      expect_config_validation('secret_key', 'Using development default secret key', level: :warn)
    end

    it 'logs missing production secret key failures before exiting' do
      stub_validation_logging

      ClimateControl.modify('RACK_ENV' => 'production', 'HTML2RSS_SECRET_KEY' => nil) do
        expect { described_class.validate_environment! }.to raise_error(SystemExit)
      end

      expect_config_validation('secret_key', 'Missing required secret key')
    end
  end

  describe '.validate_production_security!' do
    it 'logs weak production secret keys before exiting' do
      stub_validation_logging

      ClimateControl.modify(
        'RACK_ENV' => 'production',
        'HTML2RSS_SECRET_KEY' => 'short-secret'
      ) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect_config_validation('secret_key', 'Invalid or weak secret key')
    end

    it 'fails boot when auto source is enabled with the placeholder create-feed token in production' do
      stub_validation_logging
      stub_placeholder_account_with_auto_source

      ClimateControl.modify(production_env) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect_config_validation(
        'access_token',
        'Placeholder create-feed token is not allowed when auto source is enabled'
      )
    end

    it 'fails boot when a scoped account keeps the placeholder create-feed token in production' do
      stub_validation_logging
      allow(Html2rss::Web::AccountManager).to receive(:accounts).and_return(
        [{ username: 'scoped-admin', token: 'CHANGE_ME_ADMIN_TOKEN', allowed_urls: ['https://example.com/*'] }]
      )
      allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(true)

      ClimateControl.modify(production_env) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect_config_validation(
        'access_token',
        'Placeholder create-feed token is not allowed when auto source is enabled'
      )
    end

    it 'fails boot with a clear validation error when an account token is malformed' do
      stub_validation_logging
      allow(Html2rss::Web::AccountManager).to receive(:accounts).and_return(
        [{ username: 'admin', token: nil, allowed_urls: ['*'] }]
      )

      ClimateControl.modify(production_env) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect_config_validation('account_tokens', 'Invalid token configuration for users: admin')
    end

    it 'fails boot when the health-check account keeps the placeholder token in production' do
      stub_validation_logging
      allow(Html2rss::Web::AccountManager).to receive(:accounts).and_return(
        [{ username: 'health-check', token: 'CHANGE_ME_HEALTH_CHECK_TOKEN', allowed_urls: [] }]
      )

      ClimateControl.modify(production_env) do
        expect { described_class.validate_production_security! }.to raise_error(SystemExit)
      end

      expect_config_validation(
        'health_check_token',
        'Placeholder health-check token is not allowed in production'
      )
    end

    it 'allows production boot when the health-check account uses a non-placeholder token' do
      stub_validation_logging
      allow(Html2rss::Web::AccountManager).to receive(:accounts).and_return(
        [{ username: 'health-check', token: 'strong-health-token-012345', allowed_urls: [] }]
      )

      ClimateControl.modify(production_env) do
        expect { described_class.validate_production_security! }.not_to raise_error
      end
    end
  end

  # @return [Hash{String=>String}]
  def production_env
    {
      'RACK_ENV' => 'production',
      'HTML2RSS_SECRET_KEY' => 'a' * 32
    }
  end

  # @return [void]
  def stub_placeholder_account_with_auto_source
    allow(Html2rss::Web::AccountManager).to receive(:accounts).and_return(
      [{ username: 'admin', token: 'CHANGE_ME_ADMIN_TOKEN', allowed_urls: ['*'] }]
    )
    allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(true)
  end
end
