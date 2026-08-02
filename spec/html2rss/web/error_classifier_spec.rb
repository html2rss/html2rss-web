# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::ErrorClassifier do
  def stub_no_feed_items_extracted
    stub_const('Html2rss::NoFeedItemsExtracted', Class.new(Html2rss::Error))
  end

  def stub_no_feed_items_extracted_with_attempts
    stub_const('Html2rss::NoFeedItemsExtracted', Class.new(Html2rss::Error) do
      def initialize(attempts:)
        @attempts = attempts
        super('No feed items extracted after auto fallback')
      end

      attr_reader :attempts
    end)
  end

  describe '.classify' do
    it 'returns the extraction-empty decision for NoFeedItemsExtracted' do
      klass = stub_no_feed_items_extracted

      expect(described_class.classify(klass.new('empty'))).to eq(described_class::EXTRACTION_EMPTY)
    end

    it 'detects NoFeedItemsExtracted through Exception#cause' do
      klass = stub_no_feed_items_extracted
      root = klass.new('empty')
      wrapped = StandardError.new('wrapped')
      outer = StandardError.new('outer')
      allow(outer).to receive(:cause).and_return(wrapped)
      allow(wrapped).to receive(:cause).and_return(root)

      expect(described_class.classify(outer)).to eq(described_class::EXTRACTION_EMPTY)
    end

    it 'ignores attempts payload when mapping HTTP semantics' do
      klass = stub_no_feed_items_extracted_with_attempts
      error = klass.new(attempts: [{ strategy: :faraday, items_count: 0 }])

      expect(described_class.classify(error)).to have_attributes(
        status: 422,
        code: 'EXTRACTION_EMPTY',
        kind: 'input',
        cacheable: true,
        retryable: false,
        next_action: 'correct_input',
        retry_action: 'none',
        message: a_string_including('could not extract feed items')
      )
    end

    it 'returns nil for unrelated errors' do
      expect(described_class.classify(StandardError.new('boom'))).to be_nil
    end
  end

  describe '.error_chain' do
    it 'walks causes without looping on cycles' do
      first = StandardError.new('first')
      second = StandardError.new('second')
      allow(first).to receive(:cause).and_return(second)
      allow(second).to receive(:cause).and_return(first)

      expect(described_class.error_chain(first)).to eq([first, second])
    end
  end
end
