# frozen_string_literal: true

if ENV['OPENAPI']
  require 'rspec/openapi'

  RSpec::OpenAPI.path = 'public/openapi.yaml'
  RSpec::OpenAPI.title = 'html2rss-web API'
  RSpec::OpenAPI.application_version = Html2rss::Web::VERSION
  RSpec::OpenAPI.openapi_version = '3.1.0'
  RSpec::OpenAPI.enable_example = false
  RSpec::OpenAPI.enable_example_summary = false
  RSpec::OpenAPI.example_types = [:request]
  RSpec::OpenAPI.request_headers = ['Authorization']
  RSpec::OpenAPI.response_headers = %w[Retry-After Vary Link Cache-Control]
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
  RSpec::OpenAPI.root_tags = [
    { name: 'Root', description: 'API metadata and service-level information.' },
    { name: 'Catalog', description: 'Public feed-directory catalog metadata.' },
    { name: 'Health', description: 'Health and readiness endpoints.' },
    { name: 'Strategies', description: 'Feed extraction strategy discovery.' },
    { name: 'Feeds', description: 'Feed creation and feed rendering operations.' },
    { name: 'Studio', description: 'Validate, preview, and suggest refined feed configs.' }
  ]

  # Keep path keys relative to /api/v1 because servers include the versioned base path.
  RSpec::OpenAPI.post_process_hook = lambda do |_path, _records, spec|
    Openapi::Document.apply!(spec)
  end
end
