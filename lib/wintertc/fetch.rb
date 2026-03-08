# frozen_string_literal: true

require "net/http"
require "uri"

module WinterTc
  # The default maximum number of redirects that {WinterTc.fetch} will follow
  # before raising {TooManyRedirectsError}.
  MAX_REDIRECTS = 20

  # @api private
  # Maps HTTP method strings to Net::HTTP request classes.
  NET_HTTP_METHOD_MAP = {
    "GET"     => Net::HTTP::Get,
    "POST"    => Net::HTTP::Post,
    "PUT"     => Net::HTTP::Put,
    "PATCH"   => Net::HTTP::Patch,
    "DELETE"  => Net::HTTP::Delete,
    "HEAD"    => Net::HTTP::Head,
    "OPTIONS" => Net::HTTP::Options,
  }.freeze
  private_constant :NET_HTTP_METHOD_MAP

  class << self
    # Performs an HTTP request, mirroring the JavaScript
    # {https://developer.mozilla.org/en-US/docs/Web/API/fetch fetch()} function.
    #
    # Unlike the JavaScript version this method is *synchronous* — it blocks
    # until the server returns a complete response (no Promise / async / await).
    #
    # Redirects are followed automatically by default (up to {MAX_REDIRECTS}
    # hops).  On 301 / 302 / 303 responses the method is changed to GET, while
    # 307 / 308 preserve the original method — consistent with browser behaviour.
    #
    # @param input    [String, Request]  target URL string or a {Request} object.
    # @param method   [String, nil]      HTTP method (default: +"GET"+).  Ignored
    #   when +input+ is a Request and +method+ is not explicitly provided.
    # @param headers  [Hash, Headers, nil]  request headers.
    # @param body     [String, nil]      request body.
    # @param redirect [Symbol]           redirect handling strategy:
    #   * +:follow+ (default) — follow redirects transparently.
    #   * +:manual+ — return the 3xx response as-is without following.
    #   * +:error+  — raise {RedirectError} when a redirect is encountered.
    # @return [Response]
    # @raise [ArgumentError]          if the URL scheme is not http or https.
    # @raise [TooManyRedirectsError]  if more than {MAX_REDIRECTS} redirects
    #   are encountered.
    # @raise [RedirectError]          if +redirect: :error+ and a redirect
    #   response is returned.
    #
    # @example Simple GET
    #   response = WinterTc.fetch("https://example.com")
    #   puts response.status   #=> 200
    #   puts response.ok       #=> true
    #   puts response.text     #=> "<html>..."
    #
    # @example POST with a JSON body
    #   response = WinterTc.fetch(
    #     "https://api.example.com/items",
    #     method:  "POST",
    #     headers: { "Content-Type" => "application/json" },
    #     body:    JSON.generate({ name: "widget" })
    #   )
    #   item = response.json   #=> { "id" => 42, "name" => "widget" }
    #
    # @example Re-using a Request object
    #   req = WinterTc::Request.new("https://api.example.com/items", method: "GET")
    #   response = WinterTc.fetch(req)
    def fetch(input, method: nil, headers: nil, body: nil, redirect: :follow, **_opts)
      request = build_request(input, method: method, headers: headers, body: body)
      perform(request, redirect: redirect, hops: 0)
    end

    private

    # Builds a {Request} from a URL string or existing Request, applying
    # any extra keyword-argument overrides.
    def build_request(input, method:, headers:, body:)
      if input.is_a?(Request)
        Request.new(input, method: method, headers: headers, body: body)
      else
        Request.new(input.to_s, method: method, headers: headers, body: body)
      end
    end

    # Executes the HTTP request, handling redirects recursively.
    def perform(request, redirect:, hops:)
      uri     = parse_uri(request.url)
      net_req = build_net_request(request, uri)  # validate method before opening a socket

      net_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(net_req)
      end

      if net_response.is_a?(Net::HTTPRedirection)
        handle_redirect(net_response, request, redirect: redirect, hops: hops)
      else
        build_response(net_response, url: request.url)
      end
    end

    # Parses a URL string into a URI, raising ArgumentError for non-HTTP(S) URLs.
    def parse_uri(url)
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTP)
        raise ArgumentError, "Only http and https URLs are supported; got: #{url.inspect}"
      end

      uri
    end

    # Builds a Net::HTTP request object from a {Request}.
    def build_net_request(request, uri)
      klass = NET_HTTP_METHOD_MAP[request.method] ||
        raise(UnsupportedMethodError, "Unsupported HTTP method: #{request.method}")

      net_req = klass.new(uri.request_uri)
      request.headers.each { |name, value| net_req[name] = value }
      net_req.body = request.body if request.body
      net_req
    end

    # Handles a 3xx redirect response according to the +redirect+ strategy.
    def handle_redirect(net_response, original_request, redirect:, hops:)
      case redirect
      when :follow
        if hops >= MAX_REDIRECTS
          raise TooManyRedirectsError,
                "Too many redirects (maximum is #{MAX_REDIRECTS})"
        end

        location = net_response["location"]
        unless location
          raise RedirectError,
                "Redirect response (#{net_response.code}) is missing a Location header"
        end
        new_url  = resolve_url(location, original_request.url)

        # 301/302/303 → change to GET; 307/308 → preserve original method.
        new_method = case net_response.code.to_i
                     when 307, 308 then original_request.method
                     else "GET"
                     end
        new_request = Request.new(new_url, method: new_method)
        perform(new_request, redirect: :follow, hops: hops + 1)

      when :error
        raise RedirectError,
              "Unexpected redirect (#{net_response.code}) to #{net_response["location"]}"

      when :manual
        build_response(net_response, url: original_request.url)

      else
        raise ArgumentError, "Unknown redirect option: #{redirect.inspect}"
      end
    end

    # Converts a Net::HTTPResponse into a {Response}.
    def build_response(net_response, url:)
      headers = Headers.new
      net_response.each_header { |k, v| headers.set(k, v) }
      Response.new(
        status:  net_response.code.to_i,
        headers: headers,
        body:    net_response.body,
        url:     url,
      )
    end

    # Resolves a (possibly relative) redirect location against the base URL.
    def resolve_url(location, base_url)
      if location.start_with?("http://", "https://")
        location
      else
        URI.join(base_url, location).to_s
      end
    end
  end
end
