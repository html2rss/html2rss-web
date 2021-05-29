# frozen_string_literal: true

source 'https://rubygems.org'

gem 'html2rss', git: 'https://github.com/html2rss/html2rss.git'
gem 'html2rss-configs', git: 'https://github.com/html2rss/html2rss-configs.git'

# Use these instead of the two above (uncomment them) when developing locally:
# gem 'html2rss', path: '../html2rss'
# gem 'html2rss-configs', path: '../html2rss-configs'

gem 'erubi'
gem 'rack-cache'
gem 'rack-timeout'
gem 'rack-unreloader'
gem 'roda'
gem 'tilt'

gem 'puma', require: false

group :development do
  gem 'byebug'
  gem 'rake', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'yard', require: false
end

group :test do
  gem 'rspec'
  gem 'simplecov', require: false
  gem 'vcr'
end
