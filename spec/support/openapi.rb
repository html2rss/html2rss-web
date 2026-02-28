# frozen_string_literal: true

return unless ENV['OPENAPI']

require 'rspec/openapi'

RSpec::OpenAPI.path = 'docs/api/v1/openapi.yaml'
RSpec::OpenAPI.title = 'html2rss-web API'
RSpec::OpenAPI.application_version = '1.0.0'
RSpec::OpenAPI.enable_example = false
RSpec::OpenAPI.enable_example_summary = false
RSpec::OpenAPI.example_types = [:request]
RSpec::OpenAPI.request_headers = ['Authorization']
RSpec::OpenAPI.servers = [
  { url: 'https://html2rss-web.example.com/api/v1', description: 'Production server' },
  { url: 'http://localhost:4000/api/v1', description: 'Development server' }
]
RSpec::OpenAPI.info = {
  description: 'RESTful API for converting websites to RSS feeds.',
  contact: {
    name: 'html2rss-web Support',
    url: 'https://github.com/html2rss/html2rss-web'
  },
  license: {
    name: 'MIT',
    url: 'https://opensource.org/licenses/MIT'
  }
}
RSpec::OpenAPI.security_schemes = {
  'BearerAuth' => {
    description: 'Bearer token authentication for API access.',
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'JWT'
  }
}

RSpec::OpenAPI.summary_builder = lambda { |example|
  example.metadata.dig(:example_group, :openapi, :summary) || example.metadata[:summary]
}
RSpec::OpenAPI.tags_builder = lambda { |example|
  example.metadata.dig(:example_group, :openapi, :tags) || example.metadata[:tags]
}

# Keep path keys relative to /api/v1 because servers include the versioned base path.
RSpec::OpenAPI.post_process_hook = lambda do |_path, _records, spec|
  stringify = lambda do |value|
    case value
    when Hash
      value.each_with_object({}) { |(key, nested_value), mapped| mapped[key.to_s] = stringify.call(nested_value) }
    when Array
      value.map { |item| stringify.call(item) }
    else
      value
    end
  end

  path_map = spec['paths'] || spec[:paths]
  next unless path_map.is_a?(Hash)

  normalized_paths = {}
  path_map.each do |raw_path, operation|
    original_path = raw_path.to_s
    normalized = if original_path.match?(%r{\A/api/v1/feeds/[^/]+\z})
                   '/feeds/{token}'
                 elsif original_path.start_with?('/api/v1')
                   original_path.delete_prefix('/api/v1')
                 else
                   original_path
                 end
    normalized = '/' if normalized.empty?
    normalized_paths[normalized] ||= {}

    stringify.call(operation).each do |verb, operation_doc|
      existing = normalized_paths[normalized][verb]

      if existing
        merged = existing.merge(operation_doc)
        merged['responses'] = (existing['responses'] || {}).merge(operation_doc['responses'] || {})
        merged['parameters'] = [*(existing['parameters'] || []), *(operation_doc['parameters'] || [])]
        merged['parameters'].uniq! { |parameter| [parameter['name'], parameter['in']] }
        normalized_paths[normalized][verb] = merged
      else
        normalized_paths[normalized][verb] = operation_doc
      end

      next unless normalized == '/feeds/{token}'

      normalized_paths[normalized][verb]['parameters'] ||= []
      has_token_param = normalized_paths[normalized][verb]['parameters'].any? do |parameter|
        parameter['name'] == 'token' && parameter['in'] == 'path'
      end
      next if has_token_param

      normalized_paths[normalized][verb]['parameters'] << {
        'name' => 'token',
        'in' => 'path',
        'required' => true,
        'schema' => { 'type' => 'string' }
      }
    end
  end

  if spec.key?('paths')
    spec['paths'] = normalized_paths
  else
    spec[:paths] = normalized_paths
  end
end
