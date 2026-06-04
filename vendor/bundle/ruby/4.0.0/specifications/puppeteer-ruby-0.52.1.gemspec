# -*- encoding: utf-8 -*-
# stub: puppeteer-ruby 0.52.1 ruby lib

Gem::Specification.new do |s|
  s.name = "puppeteer-ruby".freeze
  s.version = "0.52.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["YusukeIwaki".freeze]
  s.bindir = "exe".freeze
  s.date = "2026-05-01"
  s.email = ["q7w8e9w8q7w8e9@yahoo.co.jp".freeze]
  s.homepage = "https://github.com/YusukeIwaki/puppeteer-ruby".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A ruby port of puppeteer".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<async>.freeze, [">= 2.35.1".freeze, "< 3.0".freeze])
  s.add_runtime_dependency(%q<async-http>.freeze, [">= 0.60".freeze, "< 1.0".freeze])
  s.add_runtime_dependency(%q<async-websocket>.freeze, [">= 0.27".freeze, "< 1.0".freeze])
  s.add_runtime_dependency(%q<base64>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<mime-types>.freeze, [">= 3.0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<chunky_png>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<dry-inflector>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<pry-byebug>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.3.1".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.13.2".freeze])
  s.add_development_dependency(%q<rspec_junit_formatter>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rbs-inline>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.84.0".freeze])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 3.9.0".freeze])
  s.add_development_dependency(%q<sinatra>.freeze, ["< 5.0.0".freeze])
  s.add_development_dependency(%q<steep>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<webrick>.freeze, [">= 0".freeze])
end
