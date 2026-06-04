# URL Parsing

This guide explains how to use `Protocol::HTTP::URL` for parsing and manipulating URL components, particularly query strings and parameters.

## Overview

{ruby Protocol::HTTP::URL} provides utilities for parsing and manipulating URL components, particularly query strings and parameters. It offers robust encoding/decoding capabilities for complex parameter structures.

While basic query parameter encoding follows the `application/x-www-form-urlencoded` standard, there is no universal standard for serializing complex nested structures (arrays, nested objects) in URLs. Different frameworks use varying conventions for these cases, and this implementation follows common patterns where possible.

## Basic Query Parameter Parsing

``` ruby
require "protocol/http/url"

# Parse query parameters from a URL:
reference = Protocol::HTTP::Reference.parse("/search?q=ruby&category=programming&page=2")
parameters = Protocol::HTTP::URL.decode(reference.query)
# => {"q" => "ruby", "category" => "programming", "page" => "2"}

# Symbolize keys for easier access:
parameters = Protocol::HTTP::URL.decode(reference.query, symbolize_keys: true)
# => {:q => "ruby", :category => "programming", :page => "2"}
```

## Complex Parameter Structures

The URL module handles nested parameters, arrays, and complex data structures:

``` ruby
# Array parameters:
query = "tags[]=ruby&tags[]=programming&tags[]=web"
parameters = Protocol::HTTP::URL.decode(query)
# => {"tags" => ["ruby", "programming", "web"]}

# Nested hash parameters:
query = "user[name]=John&user[email]=john@example.com&user[preferences][theme]=dark"
parameters = Protocol::HTTP::URL.decode(query)
# => {"user" => {"name" => "John", "email" => "john@example.com", "preferences" => {"theme" => "dark"}}}

# Mixed structures:
query = "filters[categories][]=books&filters[categories][]=movies&filters[price][min]=10&filters[price][max]=100"
parameters = Protocol::HTTP::URL.decode(query)
# => {"filters" => {"categories" => ["books", "movies"], "price" => {"min" => "10", "max" => "100"}}}
```

## Encoding Parameters to Query Strings

``` ruby
# Simple parameters:
parameters = {"search" => "protocol-http", "limit" => "20"}
query = Protocol::HTTP::URL.encode(parameters)
# => "search=protocol-http&limit=20"

# Array parameters:
parameters = {"tags" => ["ruby", "http", "protocol"]}
query = Protocol::HTTP::URL.encode(parameters)
# => "tags[]=ruby&tags[]=http&tags[]=protocol"

# Nested parameters:
parameters = {
	user: {
		profile: {
			name: "Alice",
			settings: {
				notifications: true,
				theme: "light"
			}
		}
	}
}
query = Protocol::HTTP::URL.encode(parameters)
# => "user[profile][name]=Alice&user[profile][settings][notifications]=true&user[profile][settings][theme]=light"
```

## URL Escaping and Unescaping

``` ruby
# Escape special characters:
Protocol::HTTP::URL.escape("hello world!")
# => "hello%20world%21"

# Escape path components (preserves path separators):
Protocol::HTTP::URL.escape_path("/path/with spaces/file.html")
# => "/path/with%20spaces/file.html"

# Unescape percent-encoded strings:
Protocol::HTTP::URL.unescape("hello%20world%21")
# => "hello world!"

# Handle Unicode characters:
Protocol::HTTP::URL.escape("café")
# => "caf%C3%A9"

Protocol::HTTP::URL.unescape("caf%C3%A9")
# => "café"
```

## Scanning and Processing Query Strings

For custom processing, you can scan query strings directly:

``` ruby
query = "name=John&age=30&active=true"

Protocol::HTTP::URL.scan(query) do |key, value|
	puts "#{key}: #{value}"
end
# Output:
# name: John
# age: 30
# active: true
```

## Security and Limits

The URL module includes built-in protection against deeply nested parameter attacks:

``` ruby
# This will raise an error to prevent excessive nesting:
begin
	Protocol::HTTP::URL.decode("a[b][c][d][e][f][g][h][i]=value")
rescue ArgumentError => error
	puts error.message
	# => "Key length exceeded limit!"
end

# You can adjust the maximum nesting level:
Protocol::HTTP::URL.decode("a[b][c]=value", 5)  # Allow up to 5 levels of nesting
```
