# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app/web/config/flags'

RSpec.describe Html2rss::Web::Flags do
  describe '.auto_source_enabled?' do
    it 'defaults to true in development when unset' do
      ClimateControl.modify('RACK_ENV' => 'development', 'AUTO_SOURCE_ENABLED' => nil) do
        expect(described_class.auto_source_enabled?).to be(true)
      end
    end

    it 'defaults to false in production when unset' do
      ClimateControl.modify('RACK_ENV' => 'production', 'AUTO_SOURCE_ENABLED' => nil) do
        expect(described_class.auto_source_enabled?).to be(false)
      end
    end
  end

  describe '.validate!' do
    it 'raises for malformed boolean values' do
      ClimateControl.modify('AUTO_SOURCE_ENABLED' => 'not-a-bool') do
        expect { described_class.validate! }.to raise_error(ArgumentError, /Malformed flag 'AUTO_SOURCE_ENABLED'/)
      end
    end

    it 'raises for unknown managed feature keys' do
      ClimateControl.modify('AUTO_SOURCE_ENABLED_EXTRA' => 'true') do
        expect { described_class.validate! }.to raise_error(ArgumentError, /Unknown feature flags/)
      end
    end

    it 'raises for malformed stale factor' do
      ClimateControl.modify('ASYNC_FEED_REFRESH_STALE_FACTOR' => '0') do
        expect { described_class.validate! }.to raise_error(ArgumentError, /failed constraints/)
      end
    end
  end
end
