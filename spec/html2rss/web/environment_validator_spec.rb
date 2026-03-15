# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app/web/config/environment_validator'

RSpec.describe Html2rss::Web::EnvironmentValidator do
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
