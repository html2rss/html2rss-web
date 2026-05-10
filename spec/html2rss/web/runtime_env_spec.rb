# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app/web/config/runtime_env'

RSpec.describe Html2rss::Web::RuntimeEnv do
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
end
