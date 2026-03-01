# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/local_config'

RSpec.describe Html2rss::Web::LocalConfig do
  before do
    described_class.reload!
  end

  describe '.find' do
    it 'strips feed extensions before lookup', :aggregate_failures do
      allow(described_class).to receive(:yaml).and_return(
        { feeds: { example: { title: 'Example' } } }
      )

      expect(described_class.find('example.rss')[:title]).to eq('Example')
      expect(described_class.find('example.xml')[:title]).to eq('Example')
    end
  end

  describe '.snapshot' do
    let(:yaml_fixture) do
      {
        auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] },
        feeds: {}
      }
    end

    it 'builds typed account models from configuration' do
      allow(described_class).to receive(:yaml).and_return(yaml_fixture)
      described_class.reload!

      expect(described_class.snapshot.accounts.first.username).to eq('alice')
    end
  end
end
