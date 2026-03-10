# frozen_string_literal: true

require_relative "lib/wintertc/version"

Gem::Specification.new do |spec|
  spec.name    = "wintertc"
  spec.version = WinterTc::VERSION
  spec.authors = ["kuboon"]

  spec.summary     = "JavaScript-like Fetch API for Ruby"
  spec.description = <<~DESC
    WinterTc provides a Ruby HTTP client whose interface mirrors the JavaScript
    Fetch API as closely as possible.  It exposes WinterTc::Request,
    WinterTc::Response, WinterTc::Headers, and WinterTc.fetch — all with the
    same semantics as their browser counterparts.  No runtime gem dependencies:
    only Ruby's built-in net/http, uri, and json are used.
  DESC
  spec.homepage = "https://github.com/kuboon/wintertc.rb"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["github_repo"] = "ssh://github.com/kuboon/wintertc.rb"

  # Include only the files that belong in the published gem.
  spec.files = Dir[
    "lib/**/*",
    "sig/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md",
  ]

  spec.require_paths = ["lib"]

  # No runtime dependencies — only the Ruby standard library is used.

  spec.add_development_dependency "minitest", "~> 5"
  spec.add_development_dependency "rake",     "~> 13"
end
