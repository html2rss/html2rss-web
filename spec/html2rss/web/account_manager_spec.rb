# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app/web/security/account_manager'

RSpec.describe Html2rss::Web::AccountManager do
  describe '.get_account' do
    it 'returns the admin account by token from RuntimeEnv' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'token-1') do
        described_class.reload!

        account = described_class.get_account('token-1')

        expect(account).to include(username: 'admin', token: 'token-1', allowed_urls: ['*'])
      end
    end

    it 'falls back to the admin placeholder when HTML2RSS_ACCESS_TOKEN is unset' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => nil) do
        described_class.reload!

        account = described_class.get_account(Html2rss::Web::RuntimeEnv::ADMIN_ACCESS_TOKEN_PLACEHOLDER)

        expect(account).to include(username: 'admin', allowed_urls: ['*'])
      end
    end
  end

  describe '.reload!' do
    it 'keeps memoized snapshot before reload' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'token-1') do
        described_class.reload!
        described_class.get_account('token-1')
      end

      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'token-2') do
        expect(described_class.get_account('token-2')).to be_nil
      end
    end

    it 'clears memoized snapshot after reload' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'token-1') do
        described_class.reload!
        described_class.get_account('token-1')
      end

      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'token-2') do
        described_class.reload!
        expect(described_class.get_account('token-2')).to include(username: 'admin')
      end
    end
  end

  describe '.get_account_by_username' do
    it 'returns account by username from the memoized snapshot' do
      ClimateControl.modify('HTML2RSS_ACCESS_TOKEN' => 'token-1') do
        described_class.reload!

        account = described_class.get_account_by_username('admin')

        expect(account).to include(username: 'admin', token: 'token-1')
      end
    end
  end

  describe 'health-check account' do
    it 'omits health-check when HEALTH_CHECK_TOKEN is unset or placeholder', :aggregate_failures do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => nil) do
        described_class.reload!
        expect(described_class.get_account_by_username('health-check')).to be_nil
      end

      ClimateControl.modify(
        'HEALTH_CHECK_TOKEN' => Html2rss::Web::RuntimeEnv::HEALTH_CHECK_TOKEN_PLACEHOLDER
      ) do
        described_class.reload!
        expect(described_class.get_account_by_username('health-check')).to be_nil
      end
    end

    it 'includes health-check when HEALTH_CHECK_TOKEN is a real value' do
      ClimateControl.modify('HEALTH_CHECK_TOKEN' => 'real-health-token') do
        described_class.reload!

        expect(described_class.get_account_by_username('health-check')).to include(
          username: 'health-check',
          token: 'real-health-token',
          allowed_urls: []
        )
      end
    end
  end
end
