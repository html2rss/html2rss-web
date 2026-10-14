# frozen_string_literal: true

require_relative '../../../support/openapi/json_schema'

RSpec.describe Openapi::JsonSchema do
  describe '.components' do
    subject(:components) { described_class.components }

    # rubocop:disable-next RSpec/ExampleLength -- one mounted-schema contract example
    it 'translates the mounted gem selectors schema into OpenAPI 3.1 components',
       :aggregate_failures do
      root = components.fetch('SelectorsDocument')
      denied = %w[channel request strategy headers]
      dump = JSON.generate(components)

      denied.each do |name|
        expect(components).not_to have_key(name)
        expect(root.fetch('properties')).not_to have_key(name)
      end

      expect(root).to have_key('patternProperties')
      expect(components.dig('Html2rssPostProcessorGsub', 'properties', 'name')).to include(
        'const' => 'gsub'
      )
      expect(components.dig('Html2rssPostProcessorGsub', 'properties', 'name')).not_to have_key('enum')
      expect(root.dig('properties', 'items', 'properties', 'order')).to have_key('not')
      expect(
        root.dig('properties', 'items', 'properties', 'pagination', 'oneOf', 0, 'exclusiveMinimum')
      ).to eq(0)
      expect(dump).not_to include('#/$defs/post_processors/gsub')
      expect(dump).to include('#/components/schemas/Html2rssPostProcessorGsub')
      expect(dump).not_to include('nullable')
    end

    it 'preserves a type union that includes null as an array', :aggregate_failures do
      title = {
        'type' => 'object',
        'properties' => {
          'selectors' => {
            'type' => 'object',
            'properties' => { 'title' => { 'type' => %w[string null] } }
          }
        },
        '$defs' => {}
      }.then { described_class.components(it).dig('SelectorsDocument', 'properties', 'title') }

      expect(title).to eq('type' => %w[string null])
      expect(JSON.generate(title)).not_to include('nullable')
    end

    [
      ['unknown keyword', { 'type' => 'object', 'mystery' => true }, %r{/properties/selectors/mystery}],
      [
        'unknown $ref target shape',
        { 'type' => 'object', '$ref' => '#/definitions/other' },
        %r{/properties/selectors/\$ref}
      ]
    ].each do |label, selectors, pointer|
      it "raises Unsupported for #{label}" do
        document = {
          'type' => 'object',
          'properties' => { 'selectors' => selectors },
          '$defs' => {}
        }

        expect { described_class.components(document) }
          .to raise_error(Openapi::JsonSchema::Unsupported, pointer)
      end
    end
  end
end
