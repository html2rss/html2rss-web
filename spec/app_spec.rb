# frozen_string_literal: true

require 'spec_helper'
require_relative '../app'

RSpec.describe App do
  it { expect(described_class).to be_a Module }
  it { expect(described_class::App).to be < Roda }
end
