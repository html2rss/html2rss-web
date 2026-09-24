# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Openapi::Document do
  def studio_posts = Html2rss::Web::Routes::ApiV1::FeedRoutes::STUDIO_POSTS

  def get_operation(description: 'ok', summary: nil)
    {
      get: {
        summary: summary || description,
        description:,
        responses: { '200': { description: } }
      }
    }
  end

  def apply!(paths: nil, components: {}, extra: {})
    spec = { paths: paths || {}, components: { schemas: {} } }.merge(extra)
    described_class.apply!(spec, components:)
    spec
  end

  # rubocop:disable-next Metrics/MethodLength -- dense OpenAPI hull fixture
  def studio_hull_spec(nullable_echo: true)
    echo = {
      type: 'object',
      properties: {
        items: {
          type: 'object',
          properties: { selector: { type: 'string' } }
        }
      }
    }
    echo[:nullable] = true if nullable_echo

    {
      paths: {
        '/feeds/preview': {
          post: {
            requestBody: {
              content: {
                'application/json': {
                  schema: {
                    type: 'object',
                    properties: {
                      selectors: {
                        type: 'object',
                        properties: {
                          items: {
                            type: 'object',
                            properties: { selector: { type: 'string' } }
                          }
                        }
                      }
                    }
                  }
                }
              }
            },
            responses: {
              '200': {
                content: {
                  'application/json': {
                    schema: {
                      type: 'object',
                      properties: {
                        data: {
                          type: 'object',
                          properties: {
                            sample_items: {
                              type: 'array',
                              items: {
                                type: 'object',
                                properties: { title: { type: 'string' } }
                              }
                            },
                            candidates: {
                              type: 'object',
                              properties: {
                                items: { type: 'array' },
                                title: { type: 'array' },
                                link: { type: 'array' },
                                published: { type: 'array' }
                              }
                            },
                            selectors: echo
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      components: { schemas: {} }
    }
  end

  def issue_hull_spec
    properties = %i[actual code expected message path].to_h { [it, { type: 'string' }] }
    {
      components: {
        schemas: { ValidationIssue: { type: 'object', properties: } }
      },
      paths: {}
    }
  end

  describe Openapi::PathTemplate do
    [
      ['/api/v1', '/'],
      ['/api/v1/feeds', '/feeds'],
      ['/api/v1/feeds/validate', '/feeds/validate'],
      ['/api/v1/feeds/preview', '/feeds/preview'],
      ['/api/v1/feeds/suggest_selectors', '/feeds/suggest_selectors'],
      ['/api/v1/feeds/abc123', '/feeds/{token}'],
      ['/feeds/{token}', '/feeds/{token}']
    ].each do |raw, expected|
      it "maps #{raw} to #{expected}" do
        expect(described_class.normalize(raw, studio_posts:)).to eq(expected)
      end
    end
  end

  # rubocop:disable-next RSpec/ExampleLength -- path collapse contract in one example
  it 'collapses studio and token paths while keeping symbol keys', :aggregate_failures do
    spec = apply!(
      paths: {
        '/api/v1/feeds/validate': get_operation(description: 'validate'),
        '/api/v1/feeds/preview': get_operation(description: 'preview'),
        '/api/v1/feeds/suggest_selectors': get_operation(description: 'suggest'),
        '/api/v1/feeds/abc123': get_operation(description: 'token a'),
        '/api/v1/feeds/def456': get_operation(description: 'token a')
      }
    )

    expect(spec[:paths].keys).to contain_exactly(
      :'/feeds/validate', :'/feeds/preview', :'/feeds/suggest_selectors', :'/feeds/{token}'
    )
    expect(spec[:paths].keys).to all(be_a(Symbol))
  end

  it 'merges token operations and inserts the path parameter', :aggregate_failures do
    spec = apply!(
      paths: {
        '/api/v1/feeds/one': get_operation(description: 'same'),
        '/api/v1/feeds/two': get_operation(description: 'same')
      }
    )
    get = spec.dig(:paths, :'/feeds/{token}', :get)

    expect(get[:parameters]).to include(
      name: 'token', in: 'path', required: true, schema: { type: 'string' }
    )
    expect(get.dig(:responses, :'200', :description)).to eq('same')
  end

  it 'raises when merged operations contribute conflicting descriptions' do
    expect do
      apply!(
        paths: {
          '/api/v1/feeds/one': get_operation(description: 'alpha'),
          '/api/v1/feeds/two': get_operation(description: 'beta')
        }
      )
    end.to raise_error(Openapi::Document::ConflictError, /alpha | beta|beta | alpha/)
  end

  it 'stamps issue code enums and open expected/actual schemas', :aggregate_failures do
    spec = issue_hull_spec
    described_class.apply!(spec, components: {})

    code = spec.dig(:components, :schemas, :ValidationIssue, :properties, :code)
    expect(code[:enum]).to eq(Html2rss::Config::CODES.map(&:to_s).sort)
    expect(code[:type]).to eq('string')

    %i[expected actual].each do |field|
      expect(spec.dig(:components, :schemas, :ValidationIssue, :properties, field)).to eq(
        description: Openapi::Document::OPEN_VALUE_DESCRIPTION
      )
    end
  end

  it 'publishes web schemas with 3.1 null sample fields and no nullable keys', :aggregate_failures do
    spec = apply!
    sample = spec.dig(:components, :schemas, :PreviewSampleItem)

    expect(sample[:required]).to eq(%w[title])
    expect(sample[:properties][:title]).to eq(type: 'string')
    expect(sample[:properties][:url]).to eq(type: %w[string null])
    expect(sample[:properties][:image]).to eq(type: %w[string null])
    expect(spec.to_s).not_to include('nullable')

    expect(spec.dig(:components, :schemas).keys).to include(
      :PreviewSampleItem, :SelectorCandidates, :ItemsSelectorCandidate, :FieldSelectorCandidate
    )
    expect(spec.dig(:components, :schemas)).not_to have_key(:SelectorsDocument)
  end

  it 'merges JsonSchema.components when components are omitted', :aggregate_failures do
    spec = studio_hull_spec
    described_class.apply!(spec)

    expect(spec.dig(:components, :schemas)).to have_key(:SelectorsDocument)
    request_selectors = spec.dig(
      :paths, :'/feeds/preview', :post, :requestBody, :content, :'application/json',
      :schema, :properties, :selectors
    )
    expect(request_selectors).to eq('$ref': '#/components/schemas/SelectorsDocument')
  end

  # rubocop:disable-next RSpec/ExampleLength -- hull leave-alone contract in one example
  it 'leaves selector hulls alone when SelectorsDocument is absent', :aggregate_failures do
    spec = studio_hull_spec
    described_class.apply!(spec, components: {})

    request_selectors = spec.dig(
      :paths, :'/feeds/preview', :post, :requestBody, :content, :'application/json',
      :schema, :properties, :selectors
    )
    expect(request_selectors[:type]).to eq('object')
    expect(request_selectors).not_to have_key(:$ref)

    sample_items = spec.dig(
      :paths, :'/feeds/preview', :post, :responses, :'200', :content, :'application/json',
      :schema, :properties, :data, :properties, :sample_items
    )
    expect(sample_items).to eq(type: 'array', items: { '$ref': '#/components/schemas/PreviewSampleItem' })
  end

  # rubocop:disable-next RSpec/ExampleLength -- hull rewrite + oneOf contract in one example
  it 'rewrites selector hulls to refs and nullable echoes to oneOf when present', :aggregate_failures do
    spec = studio_hull_spec
    described_class.apply!(
      spec,
      components: { 'SelectorsDocument' => { 'type' => 'object' } }
    )

    request_selectors = spec.dig(
      :paths, :'/feeds/preview', :post, :requestBody, :content, :'application/json',
      :schema, :properties, :selectors
    )
    expect(request_selectors).to eq('$ref': '#/components/schemas/SelectorsDocument')

    echo = spec.dig(
      :paths, :'/feeds/preview', :post, :responses, :'200', :content, :'application/json',
      :schema, :properties, :data, :properties, :selectors
    )
    expect(echo).to eq(
      oneOf: [
        { type: 'null' },
        { '$ref': '#/components/schemas/SelectorsDocument' }
      ]
    )

    candidates = spec.dig(
      :paths, :'/feeds/preview', :post, :responses, :'200', :content, :'application/json',
      :schema, :properties, :data, :properties, :candidates
    )
    expect(candidates).to eq('$ref': '#/components/schemas/SelectorCandidates')
    expect(spec.to_s).not_to include('nullable')
  end

  it 'deep-sorts keys and keeps top-level keys as symbols', :aggregate_failures do
    spec = apply!(
      paths: { '/api/v1/feeds': get_operation(description: 'feeds') },
      extra: { openapi: '3.1.0', info: { title: 't', z: 1, a: 2 } }
    )

    expect(spec.keys).to eq(%i[components info openapi paths])
    expect(spec[:info].keys).to eq(%i[a title z])
    expect(spec[:paths].keys).to all(be_a(Symbol))
  end
end
