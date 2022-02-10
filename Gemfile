# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'html2rss', github: 'html2rss/html2rss'
gem 'html2rss-configs', github: 'html2rss/html2rss-configs'

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
