# wintertc.rb

[![CI](https://github.com/kuboon/wintertc.rb/actions/workflows/ci.yml/badge.svg)](https://github.com/kuboon/wintertc.rb/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/wintertc.svg)](https://badge.fury.io/rb/wintertc)

A Ruby HTTP client whose interface mirrors the JavaScript
[Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) as
closely as possible.

**No runtime gem dependencies** — only Ruby's built-in `net/http`, `uri`, and
`json` standard-library modules are used.

## Installation

Add to your `Gemfile`:

```ruby
gem "wintertc"
```

or install directly:

```
gem install wintertc
```

## Quick Start

```ruby
require "wintertc"

# Simple GET
response = WinterTc.fetch("https://httpbin.org/get")
puts response.status        # => 200
puts response.ok            # => true
puts response.json["url"]   # => "https://httpbin.org/get"

# POST with a JSON body
response = WinterTc.fetch(
  "https://httpbin.org/post",
  method:  "POST",
  headers: { "Content-Type" => "application/json" },
  body:    JSON.generate({ hello: "world" })
)
puts response.json["json"]  # => {"hello"=>"world"}

# Re-use a Request object
req = WinterTc::Request.new("https://httpbin.org/get")
response = WinterTc.fetch(req)
```

## API Reference

### `WinterTc.fetch(input, **options) → Response`

Performs a synchronous HTTP request and returns a `Response`.

| Option     | Type                              | Default    | Description                                         |
|------------|-----------------------------------|------------|-----------------------------------------------------|
| `method`   | `String`                          | `"GET"`    | HTTP verb (GET, POST, PUT, PATCH, DELETE, …)        |
| `headers`  | `Hash` / `WinterTc::Headers`      | `{}`       | Request headers                                     |
| `body`     | `String` / `nil`                  | `nil`      | Request body                                        |
| `redirect` | `:follow` / `:manual` / `:error`  | `:follow`  | Redirect strategy                                   |

Redirects on 301/302/303 change the method to `GET`; 307/308 preserve the
original method — consistent with browser behaviour.

### `WinterTc::Headers`

A case-insensitive header map.

```ruby
h = WinterTc::Headers.new("Content-Type" => "text/html")
h.get("content-type")   # => "text/html"
h.has("Content-Type")   # => true
h.set("Accept", "application/json")
h.append("Accept", "text/plain")
h.get("accept")         # => "application/json, text/plain"
h.delete("accept")
h.to_h                  # => {}
```

### `WinterTc::Request`

```ruby
req = WinterTc::Request.new(
  "https://api.example.com/items",
  method:  "POST",
  headers: { "Authorization" => "Bearer token" },
  body:    JSON.generate({ name: "widget" })
)
req.url     # => "https://api.example.com/items"
req.method  # => "POST"
req.headers # => #<WinterTc::Headers ...>
req.body    # => '{"name":"widget"}'

# Clone with overrides
updated = WinterTc::Request.new(req, body: JSON.generate({ name: "gadget" }))
```

### `WinterTc::Response`

```ruby
response.status       # => 200
response.ok           # => true  (status 200–299)
response.ok?          # alias for ok
response.status_text  # => "OK"
response.headers      # => #<WinterTc::Headers ...>
response.text         # => raw body string
response.json         # => parsed JSON (raises JSON::ParserError on invalid JSON)
response.url          # => final URL after redirects
```

## Error Classes

| Class                          | Raised when                                       |
|--------------------------------|---------------------------------------------------|
| `WinterTc::Error`              | Base class for all WinterTc errors                |
| `WinterTc::TooManyRedirectsError` | More than `WinterTc::MAX_REDIRECTS` redirects  |
| `WinterTc::RedirectError`      | `redirect: :error` and a redirect is received     |
| `WinterTc::UnsupportedMethodError` | An unknown HTTP verb is requested             |

## Type Signatures (RBS)

RBS signatures are shipped in `sig/wintertc.rbs` and are compatible with
[Steep](https://github.com/soutaro/steep) and other RBS-aware tools.

## Development

```
bundle install
bundle exec rake test
```

## License

[MIT](LICENSE)
