# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'html2rss', '~> 0.14'
gem 'html2rss-configs', github: 'html2rss/html2rss-configs'

# Use these instead of the two above (uncomment them) when developing locally:
# gem 'html2rss', path: '../html2rss'
# gem 'html2rss-configs', path: '../html2rss-configs'

gem 'base64'
gem 'erubi'
gem 'parallel'
gem 'rack-cache'
gem 'rack-timeout'
gem 'rack-unreloader'
gem 'roda'
gem 'ssrf_filter'
gem 'tilt'

gem 'puma', require: false

group :development do
  gem 'byebug'
  gem 'rake', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-thread_safety', require: false
  gem 'yard', require: false
end

group :test do
  gem 'climate_control'
  gem 'rack-test'
  gem 'rspec'
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webmock'
end
