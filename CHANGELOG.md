# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-08

### Added
- Initial release.
- `WinterTc::Headers` — case-insensitive HTTP header map.
- `WinterTc::Request` — immutable HTTP request object.
- `WinterTc::Response` — HTTP response with `#text`, `#json`, `#ok` helpers, and `.json` static constructor.
- `WinterTc.fetch` — synchronous Fetch-API-compatible HTTP client.
- RBS type signatures in `sig/wintertc.rbs`.
- GitHub Actions CI for Ruby 3.3, 3.4, and head.
