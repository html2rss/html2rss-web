# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::VersionGate do
  it 'compares dotted numeric versions' do
    expect(described_class.exceeds_max?('2026.08.22', '2026.08.21')).to be(true)
    expect(described_class.exceeds_max?('2026.08.21', '2026.08.22')).to be(false)
  end

  it 'strips a leading v prefix before comparing' do
    expect(described_class.exceeds_max?('v2026.08.22', '2026.08.21')).to be(true)
  end

  it 'returns false when max_version is unset' do
    expect(described_class.exceeds_max?('2026.08.22', nil)).to be(false)
  end
end
