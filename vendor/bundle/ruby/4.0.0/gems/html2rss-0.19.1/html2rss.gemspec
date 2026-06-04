# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'html2rss/version'

Gem::Specification.new do |spec|
  spec.name          = 'html2rss'
  spec.version       = Html2rss::VERSION
  spec.authors       = ['Gil Desmarais']
  spec.email         = ['html2rss@desmarais.de']

  spec.summary       = 'Generates RSS feeds from websites by scraping a URL and using CSS selectors to extract item.'
  spec.description   = 'Supports JSON content, custom HTTP headers, and post-processing of extracted content.'
  spec.homepage      = 'https://github.com/html2rss/html2rss'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
    spec.metadata['changelog_uri'] = "#{spec.homepage}/releases/tag/v#{spec.version}"
    spec.metadata['rubygems_mfa_required'] = 'true'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").select do |f|
    f.match(%r{^(lib/|exe/|schema/|README.md|LICENSE|html2rss.gemspec)})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'addressable', '~> 2.7'
  spec.add_dependency 'brotli'
  spec.add_dependency 'dry-validation'
  spec.add_dependency 'faraday', '> 2.0.1', '< 3.0'
  spec.add_dependency 'faraday-follow_redirects'
  spec.add_dependency 'faraday-gzip', '~> 3'
  spec.add_dependency 'kramdown'
  spec.add_dependency 'mime-types', '> 3.0'
  spec.add_dependency 'nokogiri', '>= 1.10', '< 2.0'
  spec.add_dependency 'parallel'
  spec.add_dependency 'puppeteer-ruby'
  spec.add_dependency 'regexp_parser'
  spec.add_dependency 'reverse_markdown', '~> 3.0'
  spec.add_dependency 'rss'
  spec.add_dependency 'sanitize'
  spec.add_dependency 'thor'
  spec.add_dependency 'tzinfo'
  spec.add_dependency 'zeitwerk'
end
