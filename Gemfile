# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Pinned by revision, not by branch. This ref is feat/suggest-selector-candidates.
# Bump it deliberately; do not swap it for `branch:` or a rubygems constraint.
gem 'html2rss', github: 'html2rss/html2rss', ref: '09d1b7964eaa3b5c50abf1f07b17d5042675f6db'
gem 'html2rss-configs', github: 'html2rss/html2rss-configs'

# Use these instead of the two above (uncomment them) when developing locally:
# gem 'html2rss', path: '../html2rss'
# gem 'html2rss-configs', path: '../html2rss-configs'

gem 'base64'
gem 'falcon'
gem 'roda'
gem 'zeitwerk'

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
