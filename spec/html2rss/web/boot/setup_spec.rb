# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Boot::Setup do
  describe '.call!' do
    before do
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_environment!)
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_production_security!)
      allow(Html2rss::Web::Flags).to receive(:validate!)
    end

    it 'validates environment state', :aggregate_failures do
      described_class.call!

      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_environment!).once
      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_production_security!).once
      expect(Html2rss::Web::Flags).to have_received(:validate!).once
    end
  end
end
