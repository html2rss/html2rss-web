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
  { url: 'https://api.html2rss.dev/api/v1', description: 'Production server' },
  { url: 'http://127.0.0.1:4000/api/v1', description: 'Development server' }
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
RSpec::OpenAPI.description_builder = lambda { |example|
  example.metadata.dig(:example_group, :openapi, :description) || example.metadata[:description] || example.description
}

# Keep path keys relative to /api/v1 because servers include the versioned base path.
RSpec::OpenAPI.post_process_hook = lambda do |_path, _records, spec|
  token_feed_error_statuses = %w[401 403 500].freeze

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

  deep_sort = lambda do |value|
    case value
    when Hash
      value.keys.sort_by(&:to_s).to_h { |key| [key, deep_sort.call(value[key])] }
    when Array
      value.map { |item| deep_sort.call(item) }
    else
      value
    end
  end

  merge_responses = lambda do |existing_responses, new_responses|
    statuses = existing_responses.keys | new_responses.keys

    statuses.each_with_object({}) do |status, merged_responses|
      current = existing_responses[status] || {}
      incoming = new_responses[status] || {}
      merged_response = current.merge(incoming)

      current_content = current['content'] || {}
      incoming_content = incoming['content'] || {}
      if current_content.any? || incoming_content.any?
        content_types = current_content.keys | incoming_content.keys
        merged_response['content'] = content_types.to_h do |content_type|
          current_entry = current_content[content_type] || {}
          incoming_entry = incoming_content[content_type] || {}
          [content_type, current_entry.merge(incoming_entry)]
        end
      end

      current_headers = current['headers'] || {}
      incoming_headers = incoming['headers'] || {}
      if current_headers.any? || incoming_headers.any?
        merged_response['headers'] = current_headers.merge(incoming_headers)
      end

      merged_response['description'] ||= current['description'] || incoming['description']
      merged_responses[status] = merged_response
    end
  end

  token_feed_error_examples = {
    'application/xml' => {
      'example' => <<~XML.strip
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel><title>Error</title><description>Internal Server Error</description></channel></rss>
      XML
    },
    'application/feed+json' => {
      'example' => '{"version":"https://jsonfeed.org/version/1.1","title":"Error"}'
    }
  }

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
        merged['responses'] = merge_responses.call(existing['responses'] || {}, operation_doc['responses'] || {})
        merged['parameters'] = [*(existing['parameters'] || []), *(operation_doc['parameters'] || [])]
        merged['parameters'].uniq! { |parameter| [parameter['name'], parameter['in']] }
        normalized_paths[normalized][verb] = deep_sort.call(merged)
      else
        normalized_paths[normalized][verb] = deep_sort.call(operation_doc)
      end

      normalized_paths[normalized][verb]['description'] ||= normalized_paths[normalized][verb]['summary']

      next unless normalized == '/feeds/{token}'

      normalized_paths[normalized][verb]['parameters'] ||= []
      has_token_param = normalized_paths[normalized][verb]['parameters'].any? do |parameter|
        parameter['name'] == 'token' && parameter['in'] == 'path'
      end
      unless has_token_param
        normalized_paths[normalized][verb]['parameters'] << {
          'name' => 'token',
          'in' => 'path',
          'required' => true,
          'schema' => { 'type' => 'string' }
        }
      end

      token_feed_error_statuses.each do |status|
        response = normalized_paths[normalized][verb].dig('responses', status)
        next unless response

        response['content'] ||= {}
        token_feed_error_examples.each do |content_type, example|
          response['content'][content_type] ||= { 'schema' => { 'type' => 'string' } }
          response['content'][content_type].merge!(example)
        end
      end
    end
  end

  if spec.key?('paths')
    spec['paths'] = deep_sort.call(normalized_paths)
  else
    spec[:paths] = deep_sort.call(normalized_paths)
  end

  tags = [
    { 'name' => 'Root', 'description' => 'API metadata and service-level information.' },
    { 'name' => 'Health', 'description' => 'Health and readiness endpoints.' },
    { 'name' => 'Strategies', 'description' => 'Feed extraction strategy discovery.' },
    { 'name' => 'Feeds', 'description' => 'Feed creation and feed rendering operations.' }
  ]

  if spec.key?('tags')
    spec['tags'] = tags
  else
    spec[:tags] = tags
  end
end
