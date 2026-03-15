# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/domain/cache_ttl'

RSpec.describe Html2rss::Web::CacheTtl do
  describe '.seconds_from_minutes' do
    it 'uses default for nil' do
      expect(described_class.seconds_from_minutes(nil)).to eq(3600)
    end

    it 'coerces numeric strings' do
      expect(described_class.seconds_from_minutes('10')).to eq(600)
    end

    it 'uses default for zero' do
      expect(described_class.seconds_from_minutes(0)).to eq(3600)
    end

    it 'uses default for negative values' do
      expect(described_class.seconds_from_minutes(-5)).to eq(3600)
    end

    it 'supports a custom default' do
      expect(described_class.seconds_from_minutes(nil, default: 120)).to eq(120)
    end
  end
end
