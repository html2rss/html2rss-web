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

  describe '.feeds_cache_max_size' do
    it 'defaults to 500 when unset' do
      ClimateControl.modify('FEEDS_CACHE_MAX_SIZE' => nil) do
        expect(described_class.feeds_cache_max_size).to eq(500)
      end
    end

    it 'returns the configured integer' do
      ClimateControl.modify('FEEDS_CACHE_MAX_SIZE' => '100') do
        expect(described_class.feeds_cache_max_size).to eq(100)
      end
    end
  end

  describe '.validate!' do
    it 'coerces non-true boolean values to false without raising' do
      ClimateControl.modify('AUTO_SOURCE_ENABLED' => 'not-a-bool') do
        expect { described_class.validate! }.not_to raise_error
        expect(described_class.auto_source_enabled?).to be(false)
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

    it 'raises for invalid feeds cache max size' do
      ClimateControl.modify('FEEDS_CACHE_MAX_SIZE' => '0') do
        expect { described_class.validate! }.to raise_error(ArgumentError, /failed constraints/)
      end
    end
  end

  describe 'boolean coercion' do
    it 'treats only "true" as true', :aggregate_failures do
      ClimateControl.modify('AUTO_SOURCE_ENABLED' => 'true') do
        expect(described_class.auto_source_enabled?).to be(true)
      end
    end

    it 'treats false, 1, 0, yes, and blank as false', :aggregate_failures do
      %w[false 1 0 yes].each do |raw|
        ClimateControl.modify('AUTO_SOURCE_ENABLED' => raw) do
          expect(described_class.auto_source_enabled?).to be(false), "expected #{raw.inspect} → false"
        end
      end

      ClimateControl.modify('RACK_ENV' => 'production', 'AUTO_SOURCE_ENABLED' => '') do
        expect(described_class.auto_source_enabled?).to be(false)
      end
    end
  end
end
