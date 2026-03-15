# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app/web/boot/setup'

RSpec.describe Html2rss::Web::Boot::Setup do
  describe '.call!' do
    before do
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_environment!)
      allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_production_security!)
      allow(Html2rss::Web::Flags).to receive(:validate!)
      allow(Html2rss::RequestService).to receive(:register_strategy)
      allow(Html2rss::RequestService).to receive(:default_strategy_name=)
      allow(Html2rss::RequestService).to receive(:unregister_strategy)
    end

    it 'validates environment state and configures the request service', :aggregate_failures do
      described_class.call!

      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_environment!).once
      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_production_security!).once
      expect(Html2rss::Web::Flags).to have_received(:validate!).once
      expect(Html2rss::RequestService).to have_received(:register_strategy)
        .with(:ssrf_filter, Html2rss::Web::SsrfFilterStrategy).once
      expect(Html2rss::RequestService).to have_received(:default_strategy_name=).with(:ssrf_filter).once
      expect(Html2rss::RequestService).to have_received(:unregister_strategy).with(:faraday).once
    end
  end
end
