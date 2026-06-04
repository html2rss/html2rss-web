# Faraday Gzip

![CI](https://github.com/bodrovis/faraday-gzip/actions/workflows/ci.yaml/badge.svg)
[![Gem](https://img.shields.io/gem/v/faraday-gzip.svg?style=flat-square)](https://rubygems.org/gems/faraday-gzip)
![Gem Total Downloads](https://img.shields.io/gem/dt/faraday-gzip)
[![Maintainability](https://qlty.sh/gh/bodrovis/projects/faraday-gzip/maintainability.svg)](https://qlty.sh/gh/bodrovis/projects/faraday-gzip)
[![Code Coverage](https://qlty.sh/gh/bodrovis/projects/faraday-gzip/coverage.svg)](https://qlty.sh/gh/bodrovis/projects/faraday-gzip)

The `Gzip` middleware for Faraday 1 and 2 adds appropriate `Accept-Encoding` request headers and automatically decompresses supported response bodies (`gzip`, `deflate`, and optionally `br`). If the `Accept-Encoding` header is not explicitly set, it defaults to `gzip,deflate` and includes `br` when [Brotli](https://github.com/miyucy/brotli) support is available. The middleware safely handles multiple and malformed `Content-Encoding` headers, and avoids modifying unsupported or streaming response bodies. This behavior is similar in spirit to Ruby's internal handling in `Net::HTTP#get`, while remaining conservative to preserve compatibility with Faraday adapters.

## Prerequisites

* faraday-gzip v3 supports only Faraday v2 and is tested with Ruby 3.0+ and JRuby 9.4+
* [faraday-gzip v2](https://github.com/bodrovis/faraday-gzip/tree/v2) supports Faraday v1 and v2 and is tested with Ruby 2.7+ and JRuby 9.4.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'faraday-gzip', '~> 3'
```

And then execute:

```
bundle install
```

Or install it yourself as:

```
gem install faraday-gzip
```

## Usage

To enable the middleware in your Faraday connection, add it as shown below:

```ruby
require 'faraday/gzip' # <=== Add this line

conn = Faraday.new(...) do |f|
  f.request :gzip # <=== Add this line
  # Additional configuration...
end
```

## Development

To contribute or make changes:

* Clone the repo
* Run `bundle` to install dependencies
* Implement your feature
* Write and run tests using `rspec .`
* Use rake build to build the gem locally if needed
* Create a new PR with your changes

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

This gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).