# frozen_string_literal: true

module WinterTc
  # Represents an HTTP request, mirroring the JavaScript
  # {https://developer.mozilla.org/en-US/docs/Web/API/Request Request} interface.
  #
  # A Request object can be passed directly to {WinterTc.fetch} instead of a
  # plain URL string.  It can also be used to clone an existing request while
  # overriding individual fields.
  #
  # @example Creating a POST request
  #   req = WinterTc::Request.new(
  #     "https://example.com/api",
  #     method:  "POST",
  #     headers: { "Content-Type" => "application/json" },
  #     body:    JSON.generate({ key: "value" })
  #   )
  #   response = WinterTc.fetch(req)
  #
  # @example Cloning a request with a different body
  #   cloned = WinterTc::Request.new(req, body: JSON.generate({ key: "new" }))
  class Request
    # The absolute URL of the request.
    # @return [String]
    attr_reader :url

    # The HTTP method in uppercase, e.g. +"GET"+ or +"POST"+.
    # @return [String]
    attr_reader :method

    # The request headers.
    # @return [Headers]
    attr_reader :headers

    # The request body, or +nil+ for requests without a body.
    # @return [String, nil]
    attr_reader :body

    # Creates a new Request.
    #
    # @param input   [String, Request] the target URL or an existing Request to
    #   clone.
    # @param method  [String, nil]  HTTP method.  Defaults to +"GET"+, or to
    #   the method of the cloned request.
    # @param headers [Hash, Headers, nil]  Additional headers.  When cloning a
    #   request the headers are merged: these values take precedence.
    # @param body    [String, nil]  Request body.  Defaults to +nil+, or to the
    #   body of the cloned request.
    # @raise [TypeError] when input is not a String or Request
    def initialize(input, method: nil, headers: nil, body: nil)
      case input
      when Request
        @url     = input.url
        @method  = (method || input.method).to_s.upcase
        @headers = merge_headers(input.headers, headers)
        @body    = body.nil? ? input.body : body
      when String
        @url     = input
        @method  = (method || "GET").to_s.upcase
        @headers = Headers.new(headers)
        @body    = body
      else
        raise TypeError, "input must be a String URL or a Request; got #{input.class}"
      end
    end

    # @return [String]
    def inspect
      "#<#{self.class} #{@method} #{@url}>"
    end

    private

    # Merges base headers with optional overrides, returning a new Headers.
    def merge_headers(base, extra)
      h = Headers.new(base)
      return h unless extra

      case extra
      when Headers then extra.each { |k, v| h.set(k, v) }
      when Hash    then extra.each { |k, v| h.set(k, v) }
      end
      h
    end
  end
end
