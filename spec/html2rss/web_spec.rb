# frozen_string_literal: true

require 'spec_helper'

require_relative '../../config/version'

RSpec.describe Html2rss::Web do
  describe 'VERSION' do
    it 'defines the canonical application release version' do
      expect(described_class::VERSION).to eq('1.0.0')
    end
  end
end
