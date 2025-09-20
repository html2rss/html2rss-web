# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/local_config'

RSpec.describe Html2rss::Web::LocalConfig do
  describe '::CONFIG_FILE' do
    it { expect(described_class::CONFIG_FILE).to eq 'config/feeds.yml' }
  end

  describe '.find' do
    context 'with inexistent name' do
      it { expect { described_class.find(:foobar) }.to raise_error(/Did not find/) }
      it { expect { described_class.find('foobar') }.to raise_error(/Did not find/) }
    end

    context 'with existing name' do
      it { expect(described_class.find(:example)).to be_a Hash }
      it { expect(described_class.find('example')).to be_a Hash }
    end
  end

  describe '.feeds' do
    it { expect(described_class.feeds).to be_a Hash }
  end

  describe '.feed_names' do
    it { expect(described_class.feed_names).to be_a Array }
  end

  describe '.global' do
    it { expect(described_class.global).to be_a Hash }
  end

  describe '.merge_global_stylesheets' do
    let(:config_with_stylesheets) do
      {
        stylesheets: [{ href: '/custom.xsl', type: 'text/xsl' }],
        feeds: {
          example: {
            channel: { url: 'https://example.com' },
            selectors: { items: { selector: 'div' } }
          }
        }
      }
    end

    let(:config_without_stylesheets) do
      {
        stylesheets: [{ href: '/rss.xsl', type: 'text/xsl' }],
        feeds: {
          example: {
            channel: { url: 'https://example.com' },
            selectors: { items: { selector: 'div' } }
          }
        }
      }
    end

    let(:config_no_global_stylesheets) do
      {
        feeds: {
          example: {
            channel: { url: 'https://example.com' },
            selectors: { items: { selector: 'div' } }
          }
        }
      }
    end

    context 'when config has no stylesheets and global has stylesheets' do
      before do
        allow(described_class).to receive(:global).and_return(config_without_stylesheets)
      end

      it 'merges global stylesheets into the config' do
        config = { channel: { url: 'https://test.com' } }
        result = described_class.merge_global_stylesheets(config)

        expect(result[:stylesheets]).to eq([{ href: '/rss.xsl', type: 'text/xsl' }])
      end

      it 'preserves original config data' do
        config = { channel: { url: 'https://test.com' } }
        result = described_class.merge_global_stylesheets(config)

        expect(result[:channel]).to eq({ url: 'https://test.com' })
      end

      it 'duplicates the config to avoid mutation' do
        config = { channel: { url: 'https://test.com' } }
        result = described_class.merge_global_stylesheets(config)

        expect(result).not_to be(config)
      end

      it 'creates a new object instance' do
        config = { channel: { url: 'https://test.com' } }
        result = described_class.merge_global_stylesheets(config)

        expect(result.object_id).not_to eq(config.object_id)
      end
    end

    context 'when config already has stylesheets' do
      before do
        allow(described_class).to receive(:global).and_return(config_without_stylesheets)
      end

      it 'does not override existing stylesheets' do
        config = { stylesheets: [{ href: '/custom.xsl', type: 'text/xsl' }] }
        result = described_class.merge_global_stylesheets(config)

        expect(result[:stylesheets]).to eq([{ href: '/custom.xsl', type: 'text/xsl' }])
      end

      it 'returns the original config without duplication' do
        config = { stylesheets: [{ href: '/custom.xsl', type: 'text/xsl' }] }
        result = described_class.merge_global_stylesheets(config)

        expect(result).to be(config)
      end
    end

    context 'when global config has no stylesheets' do
      before do
        allow(described_class).to receive(:global).and_return(config_no_global_stylesheets)
      end

      it 'returns the original config unchanged' do
        config = { channel: { url: 'https://test.com' } }
        result = described_class.merge_global_stylesheets(config)

        expect(result).to be(config)
      end

      it 'does not add stylesheets when none exist globally' do
        config = { channel: { url: 'https://test.com' } }
        result = described_class.merge_global_stylesheets(config)

        expect(result[:stylesheets]).to be_nil
      end
    end
  end

  describe '.find with stylesheet merging' do
    before do
      allow(described_class).to receive_messages(feeds: {
                                                   example: {
                                                     channel: { url: 'https://example.com' },
                                                     selectors: { items: { selector: 'div' } }
                                                   }
                                                 }, global: {
                                                   stylesheets: [{ href: '/rss.xsl', type: 'text/xsl' }]
                                                 })
    end

    it 'merges global stylesheets when finding a feed' do
      result = described_class.find('example')

      expect(result[:stylesheets]).to eq([{ href: '/rss.xsl', type: 'text/xsl' }])
    end

    it 'preserves feed configuration when finding a feed' do
      result = described_class.find('example')

      expect(result[:channel]).to eq({ url: 'https://example.com' })
    end
  end
end
