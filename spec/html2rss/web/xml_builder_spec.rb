# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require_relative '../../../app'

RSpec.describe Html2rss::Web::XmlBuilder do
  describe '.build_empty_feed_warning' do
    subject(:xml_doc) do
      xml = described_class.build_empty_feed_warning(
        url: 'https://example.com/articles',
        strategy: 'faraday',
        site_title: 'Example Site'
      )
      Nokogiri::XML(xml)
    end

    it 'uses updated channel description copy' do
      description = xml_doc.at_xpath('//channel/description').text
      expect(description).to include('We could not extract entries')
      expect(description).not_to include('different parser')
    end

    it 'uses updated item title and content text' do
      expect(xml_doc.at_xpath('//item/title').text).to eq('Preview unavailable for this source')
      expect(xml_doc.at_xpath('//item/description').text).to include('What you can do:')
    end

    it 'does not mention hidden strategy controls in item text' do
      expect(xml_doc.at_xpath('//item/description').text).not_to include('browserless strategy')
    end
  end
end
