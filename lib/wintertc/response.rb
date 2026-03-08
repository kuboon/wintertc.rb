# frozen_string_literal: true

require "json"

module WinterTc
  # Represents an HTTP response, mirroring the JavaScript
  # {https://developer.mozilla.org/en-US/docs/Web/API/Response Response} interface.
  #
  # Response objects are returned by {WinterTc.fetch}.  The raw body can be
  # read as a plain string with {#text}, or parsed as JSON with {#json}.
  #
  # @example
  #   response = WinterTc.fetch("https://api.example.com/users")
  #   if response.ok
  #     users = response.json   # => Array of user hashes
  #   else
  #     puts "Error: #{response.status} #{response.status_text}"
  #   end
  class Response
    # Mapping of common HTTP status codes to their standard reason phrases.
    STATUS_TEXTS = {
      100 => "Continue",
      101 => "Switching Protocols",
      102 => "Processing",
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      203 => "Non-Authoritative Information",
      204 => "No Content",
      205 => "Reset Content",
      206 => "Partial Content",
      301 => "Moved Permanently",
      302 => "Found",
      303 => "See Other",
      304 => "Not Modified",
      307 => "Temporary Redirect",
      308 => "Permanent Redirect",
      400 => "Bad Request",
      401 => "Unauthorized",
      402 => "Payment Required",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed",
      406 => "Not Acceptable",
      409 => "Conflict",
      410 => "Gone",
      411 => "Length Required",
      413 => "Content Too Large",
      415 => "Unsupported Media Type",
      422 => "Unprocessable Content",
      429 => "Too Many Requests",
      500 => "Internal Server Error",
      501 => "Not Implemented",
      502 => "Bad Gateway",
      503 => "Service Unavailable",
      504 => "Gateway Timeout",
    }.freeze

    # The HTTP status code (e.g. +200+, +404+).
    # @return [Integer]
    attr_reader :status

    # The response headers.
    # @return [Headers]
    attr_reader :headers

    # The URL that produced this response (the final URL after any redirects).
    # @return [String, nil]
    attr_reader :url

    # Creates a {Response} whose body is the JSON serialisation of +data+ and
    # whose +Content-Type+ header is set to +application/json+.  This mirrors
    # the JavaScript
    # {https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static
    # Response.json()} static method.
    #
    # @param data   [Object]  any JSON-serialisable value (Hash, Array, String, …)
    # @param status [Integer] HTTP status code (default: +200+)
    # @param headers [Hash, Headers, nil] additional response headers
    # @return [Response]
    #
    # @example
    #   res = WinterTc::Response.json({ message: "hello" })
    #   res.status                          #=> 200
    #   res.headers.get("content-type")     #=> "application/json"
    #   res.json                            #=> { "message" => "hello" }
    def self.json(data, status: 200, headers: nil)
      body = JSON.generate(data)
      merged = Headers.new(headers)
      merged.set("Content-Type", "application/json")
      new(status: status, headers: merged, body: body)
    end

    # Creates a new Response.
    #
    # @param status  [Integer]            HTTP status code
    # @param headers [Hash, Headers]      response headers
    # @param body    [String, nil]        raw response body
    # @param url     [String, nil]        the URL that produced the response
    def initialize(status:, headers:, body:, url: nil)
      @status  = Integer(status)
      @headers = headers.is_a?(Headers) ? headers : Headers.new(headers)
      @body    = body.to_s
      @url     = url
    end

    # Returns +true+ if the HTTP status code indicates success (200–299).
    #
    # @return [Boolean]
    def ok
      @status >= 200 && @status < 300
    end

    # Alias for {#ok} for idiomatic Ruby usage.
    alias ok? ok

    # Returns the response body as a plain +String+.
    #
    # @return [String]
    def text
      @body
    end

    # Parses the response body as JSON and returns the result.
    #
    # @return [Object] the parsed JSON value (Hash, Array, String, etc.)
    # @raise [JSON::ParserError] if the body is not valid JSON
    def json
      JSON.parse(@body)
    end

    # Returns the standard HTTP reason phrase for the {#status} code
    # (e.g. +"OK"+ for 200, +"Not Found"+ for 404).  Returns an empty
    # string for unrecognised codes.
    #
    # @return [String]
    def status_text
      STATUS_TEXTS[@status] || ""
    end

    # @return [String]
    def inspect
      "#<#{self.class} #{@status} #{status_text}>"
    end
  end
end
