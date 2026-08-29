# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Catalog::Merge do
  describe 'STARTER_FEED_IDS' do
    it 'prefers Faraday-stable IGO and gov configs' do
      expect(described_class::STARTER_FEED_IDS).to eq(
        %w[
          fao.org/newsroom
          ftc.gov/press-releases
          icrc.org/news
        ]
      )
    end

    it 'resolves each preferred id in the merged catalog' do
      catalog_ids = described_class.call.map { |entry| entry.fetch(:id) }
      expect(catalog_ids).to include(*described_class::STARTER_FEED_IDS)
    end
  end
end
