# frozen_string_literal: true

require_relative "wintertc/version"
require_relative "wintertc/error"
require_relative "wintertc/headers"
require_relative "wintertc/request"
require_relative "wintertc/response"
require_relative "wintertc/fetch"

# WinterTc is a Ruby HTTP client library that provides an interface as close as
# possible to the JavaScript
# {https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API Fetch API}.
#
# The three primary building blocks mirror their JavaScript counterparts:
#
# * {WinterTc::Headers} — a case-insensitive map of HTTP header fields.
# * {WinterTc::Request} — an immutable description of an HTTP request.
# * {WinterTc::Response} — the server's response, with helpers for reading the
#   body as text or JSON.
# * {WinterTc.fetch} — the main entry point; performs the request and returns a
#   {WinterTc::Response}.
#
# The library has **no runtime dependencies** beyond Ruby's standard library
# (`net/http`, `uri`, `json`).
#
# @example Quick start
#   require "wintertc"
#
#   # Simple GET
#   res = WinterTc.fetch("https://httpbin.org/get")
#   puts res.status        #=> 200
#   puts res.ok            #=> true
#   puts res.json["url"]   #=> "https://httpbin.org/get"
#
#   # POST with JSON
#   res = WinterTc.fetch(
#     "https://httpbin.org/post",
#     method:  "POST",
#     headers: { "Content-Type" => "application/json" },
#     body:    JSON.generate({ hello: "world" })
#   )
#   puts res.json["json"]  #=> { "hello" => "world" }
module WinterTc
end
