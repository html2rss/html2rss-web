# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/config/local_config'

RSpec.describe Html2rss::Web::LocalConfig do
  def titles_for(*names)
    names.map { |name| described_class.find(name)[:title] }
  end

  before do
    described_class.reload!
  end

  describe '.find' do
    it 'strips feed extensions before lookup' do
      allow(described_class).to receive(:yaml).and_return(
        { feeds: { example: { title: 'Example' } } }
      )

      expect(titles_for('example.json', 'example.rss', 'example.xml')).to eq(%w[Example Example Example])
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
