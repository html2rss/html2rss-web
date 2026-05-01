# frozen_string_literal: true

require 'spec_helper'

require_relative '../../config/version'

RSpec.describe Html2rss::Web do
  describe 'VERSION' do
    it 'defines the canonical application release version' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\z/)
    end
  end
end
