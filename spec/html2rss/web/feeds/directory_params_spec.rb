# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::DirectoryParams do
  it 'matches when params equal defaults', :aggregate_failures do
    expect(described_class.match?({ 'id' => 'b006wkfp' }, { 'id' => 'b006wkfp' })).to be(true)
    expect(described_class.match?({}, {})).to be(true)
  end

  it 'matches when request omits keys that have defaults' do
    expect(described_class.match?({ id: 'b006wkfp' }, {})).to be(true)
  end

  it 'rejects extra or non-default values', :aggregate_failures do
    expect(described_class.match?({ 'id' => 'b006wkfp' }, { 'id' => 'other' })).to be(false)
    expect(described_class.match?({}, { 'page' => '2' })).to be(false)
  end
end
