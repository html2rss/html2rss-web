# Hypertext References

This guide explains how to use `Protocol::HTTP::Reference` for constructing and manipulating hypertext references (URLs with parameters).

## Overview

{ruby Protocol::HTTP::Reference} is used to construct "hypertext references" which consist of a path and URL-encoded parameters. References provide a rich API for URL construction, path manipulation, and parameter handling.

## Basic Construction

``` ruby
require "protocol/http/reference"

# Simple reference with parameters:
reference = Protocol::HTTP::Reference.new("/search", nil, nil, {q: "kittens", limit: 10})
reference.to_s
# => "/search?q=kittens&limit=10"

# Parse existing URLs:
reference = Protocol::HTTP::Reference.parse("/api/users?page=2&sort=name#results")
reference.path       # => "/api/users"
reference.query      # => "page=2&sort=name"
reference.fragment   # => "results"

# To get parameters as a hash, decode the query string:
parameters = Protocol::HTTP::URL.decode(reference.query)
parameters           # => {"page" => "2", "sort" => "name"}
```

## Path Manipulation

References support sophisticated path manipulation including relative path resolution:

``` ruby
base = Protocol::HTTP::Reference.new("/api/v1/users")

# Append paths:
user_detail = base.with(path: "123")
user_detail.to_s  # => "/api/v1/users/123"

# Relative path navigation:
parent = user_detail.with(path: "../groups", pop: true)
parent.to_s  # => "/api/v1/groups"

# Absolute path replacement:
root = user_detail.with(path: "/status")
root.to_s  # => "/status"
```

## Advanced Parameter Handling

``` ruby
# Complex parameter structures:
reference = Protocol::HTTP::Reference.new("/search", nil, nil, {
	filters: {
		category: "books", 
		price: {min: 10, max: 50}
	},
	tags: ["fiction", "mystery"]
})

reference.to_s
# => "/search?filters[category]=books&filters[price][min]=10&filters[price][max]=50&tags[]=fiction&tags[]=mystery"

# Parameter merging:
base = Protocol::HTTP::Reference.new("/api", nil, nil, {version: "v1", format: "json"})
extended = base.with(parameters: {detailed: true}, merge: true)
extended.to_s
# => "/api?version=v1&format=json&detailed=true"

# Parameter replacement (using merge: false):
replaced = base.with(parameters: {format: "xml"}, merge: false)
replaced.to_s
# => "/api?format=xml"
```

## Merge Behavior and Query Strings

The `merge` parameter controls both parameter handling and query string behavior:

``` ruby
# Create a reference with both query string and parameters:
ref = Protocol::HTTP::Reference.new("/api", "existing=query", nil, {version: "v1"})
ref.to_s
# => "/api?existing=query&version=v1"

# merge: true (default) - keeps existing query string:
merged = ref.with(parameters: {new: "argument"}, merge: true)
merged.to_s
# => "/api?existing=query&version=v1&new=argument"

# merge: false with new parameters - clears query string:
replaced = ref.with(parameters: {new: "argument"}, merge: false)
replaced.to_s
# => "/api?new=argument"

# merge: false without new parameters - keeps everything:
unchanged = ref.with(path: "v2", merge: false)
unchanged.to_s
# => "/api/v2?existing=query&version=v1"
```

## URL Encoding and Special Characters

References handle URL encoding automatically:

``` ruby
# Spaces and special characters:
reference = Protocol::HTTP::Reference.new("/search", nil, nil, {
	q: "hello world",
	filter: "price > $10"
})
reference.to_s
# => "/search?q=hello%20world&filter=price%20%3E%20%2410"

# Unicode support:
unicode_ref = Protocol::HTTP::Reference.new("/files", nil, nil, {
	name: "résumé.pdf",
	emoji: "😀"
})
unicode_ref.to_s
# => "/files?name=r%C3%A9sum%C3%A9.pdf&emoji=%F0%9F%98%80"
```

## Reference Merging

References can be merged following RFC2396 URI resolution rules:

``` ruby
base = Protocol::HTTP::Reference.new("/docs/guide/")
relative = Protocol::HTTP::Reference.new("../api/reference.html")

merged = base + relative
merged.to_s  # => "/docs/api/reference.html"

# Absolute references override completely
absolute = Protocol::HTTP::Reference.new("/completely/different/path")
result = base + absolute
result.to_s  # => "/completely/different/path"
```
