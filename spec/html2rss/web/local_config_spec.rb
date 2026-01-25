# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/local_config'

RSpec.describe Html2rss::Web::LocalConfig do
  describe '.find' do
    it 'strips feed extensions before lookup', :aggregate_failures do
      allow(described_class).to receive(:yaml).and_return(
        { feeds: { example: { title: 'Example' } } }
      )

      expect(described_class.find('example.rss')[:title]).to eq('Example')
      expect(described_class.find('example.xml')[:title]).to eq('Example')
    end
  end
end
