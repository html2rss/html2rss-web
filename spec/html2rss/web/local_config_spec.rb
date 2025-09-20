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
end
