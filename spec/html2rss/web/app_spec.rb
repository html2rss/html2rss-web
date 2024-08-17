# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app'

RSpec.describe Html2rss::Web::App do
  it { expect(described_class).to be < Roda }
end
