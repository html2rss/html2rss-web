# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Until rubygems 0.28.0: git branch; local monorepo: BUNDLE_LOCAL__HTML2RSS=/path/to/html2rss
gem 'html2rss', github: 'html2rss/html2rss', branch: 'feat/registry-v1'

gem 'base64'
gem 'rack-cache'
gem 'rack-timeout'
gem 'roda'
gem 'zeitwerk'

gem 'puma', require: false

group :development do
  gem 'irb', require: false
  gem 'rake', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-thread_safety', require: false
  gem 'ruby-lsp', require: false
  gem 'yard', require: false
end

group :test do
  gem 'climate_control'
  gem 'rack-test'
  gem 'rspec'
  gem 'rspec-openapi', require: false
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webmock'
end

group :sentry do
  gem 'sentry-ruby'
  gem 'stackprof'
end
