# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SelectorsDocument OpenAPI contract' do
  describe 'accept fixtures' do
    SelectorsContractFixtures::ACCEPT.each do |label, selectors|
      it "accepts #{label} via SelectorsDocument.from_client" do
        document = Html2rss::Web::SelectorsDocument.from_client(selectors:)

        expect(document.selectors).to eq(selectors)
      end
    end
  end

  describe 'reject fixtures' do
    SelectorsContractFixtures::REJECT.each do |label, fragment|
      it "rejects #{label} with BadRequestError" do
        expect { Html2rss::Web::SelectorsDocument.from_client(fragment) }
          .to raise_error(Html2rss::Web::BadRequestError)
      end
    end
  end

  describe 'OpenAPI mount' do
    subject(:root) { Openapi::JsonSchema.components.fetch('SelectorsDocument') }

    it 'publishes items/order/pagination, keeps patternProperties, omits denied roots',
       :aggregate_failures do
      properties = root.fetch('properties')
      items_properties = properties.dig('items', 'properties')
      denied = Html2rss::Web::SelectorsDocument::DENIED_ROOT_KEYS.map(&:to_s)

      expect(properties).to have_key('items')
      expect(items_properties).to include('order', 'pagination')
      expect(root).to have_key('patternProperties')
      denied.each { expect(properties).not_to have_key(it) }
    end
  end
end
