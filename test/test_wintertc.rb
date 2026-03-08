# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "socket"
require "thread"

require_relative "../lib/wintertc"

# ---------------------------------------------------------------------------
# Minimal HTTP/1.1 test server using only stdlib (TCPServer)
# ---------------------------------------------------------------------------
module TestHelper
  # Starts a single-threaded HTTP/1.1 server on a random port.
  # Yields [host, port] to the block and shuts the server down afterwards.
  #
  # The handler proc is called with (method, path, request_headers, body)
  # and should return [status_code, response_headers_hash, body_string].
  def self.with_server(handler, &block)
    server = TCPServer.new("127.0.0.1", 0)
    port   = server.addr[1]

    thread = Thread.new do
      loop do
        client = server.accept
        serve(client, handler)
      rescue IOError, Errno::EBADF
        break
      rescue => e
        warn "TestHelper server error: #{e}"
      end
    end

    block.call("127.0.0.1", port)
  ensure
    server.close rescue nil
    thread.kill  rescue nil
  end

  def self.serve(client, handler)
    request_line = client.gets.to_s.chomp
    method, path, _http_version = request_line.split(" ", 3)

    request_headers = {}
    while (line = client.gets)
      line = line.chomp
      break if line.empty?

      name, value = line.split(": ", 2)
      request_headers[name.downcase] = value
    end

    body = nil
    if (length = request_headers["content-length"])
      body = client.read(length.to_i)
    end

    status, resp_headers, resp_body = handler.call(method, path, request_headers, body)
    resp_body ||= ""
    resp_headers = { "Content-Length" => resp_body.bytesize.to_s }.merge(resp_headers || {})

    client.print "HTTP/1.1 #{status} OK\r\n"
    resp_headers.each { |k, v| client.print "#{k}: #{v}\r\n" }
    client.print "\r\n"
    client.print resp_body
    client.close
  end
end

# ===========================================================================
# WinterTc::Headers tests
# ===========================================================================
class TestHeaders < Minitest::Test
  def test_set_and_get
    h = WinterTc::Headers.new
    h.set("Content-Type", "application/json")
    assert_equal "application/json", h.get("content-type")
    assert_equal "application/json", h.get("Content-Type")
  end

  def test_case_insensitive_get
    h = WinterTc::Headers.new("X-Custom" => "hello")
    assert_equal "hello", h.get("x-custom")
    assert_equal "hello", h.get("X-CUSTOM")
    assert_equal "hello", h.get("X-Custom")
  end

  def test_has
    h = WinterTc::Headers.new("Authorization" => "Bearer token")
    assert h.has("authorization")
    assert h.has("Authorization")
    refute h.has("accept")
  end

  def test_delete
    h = WinterTc::Headers.new("Accept" => "text/html")
    h.delete("Accept")
    refute h.has("accept")
    assert_nil h.get("accept")
  end

  def test_append_new_header
    h = WinterTc::Headers.new
    h.append("Accept", "text/html")
    assert_equal "text/html", h.get("accept")
  end

  def test_append_existing_header
    h = WinterTc::Headers.new("Accept" => "text/html")
    h.append("accept", "application/json")
    assert_equal "text/html, application/json", h.get("accept")
  end

  def test_initialize_with_hash
    h = WinterTc::Headers.new("Content-Type" => "text/plain", "Accept" => "*/*")
    assert_equal "text/plain", h.get("content-type")
    assert_equal "*/*",        h.get("accept")
  end

  def test_initialize_with_array_of_pairs
    h = WinterTc::Headers.new([["Content-Type", "text/plain"], ["Accept", "*/*"]])
    assert_equal "text/plain", h.get("content-type")
    assert_equal "*/*",        h.get("accept")
  end

  def test_initialize_with_headers
    base  = WinterTc::Headers.new("Content-Type" => "text/plain")
    clone = WinterTc::Headers.new(base)
    assert_equal "text/plain", clone.get("content-type")
    # Mutation of clone should not affect base.
    clone.set("content-type", "application/json")
    assert_equal "text/plain",       base.get("content-type")
    assert_equal "application/json", clone.get("content-type")
  end

  def test_initialize_with_nil
    h = WinterTc::Headers.new(nil)
    assert_equal 0, h.keys.length
  end

  def test_initialize_with_invalid_type
    assert_raises(TypeError) { WinterTc::Headers.new(42) }
  end

  def test_keys_and_values
    h = WinterTc::Headers.new("A" => "1", "B" => "2")
    assert_equal %w[a b], h.keys.sort
    assert_equal %w[1 2], h.values.sort
  end

  def test_to_h
    h = WinterTc::Headers.new("Content-Type" => "text/html")
    hash = h.to_h
    assert_instance_of Hash, hash
    assert_equal "text/html", hash["content-type"]
    # Should return a copy, not the internal state.
    hash["content-type"] = "changed"
    assert_equal "text/html", h.get("content-type")
  end

  def test_each_enumerable
    h = WinterTc::Headers.new("A" => "1", "B" => "2")
    pairs = h.map { |k, v| [k, v] }.sort
    assert_equal [%w[a 1], %w[b 2]], pairs
  end

  def test_inspect
    h = WinterTc::Headers.new("Content-Type" => "text/html")
    assert_includes h.inspect, "WinterTc::Headers"
    assert_includes h.inspect, "content-type"
  end
end

# ===========================================================================
# WinterTc::Request tests
# ===========================================================================
class TestRequest < Minitest::Test
  def test_defaults
    req = WinterTc::Request.new("https://example.com")
    assert_equal "https://example.com", req.url
    assert_equal "GET",                 req.method
    assert_nil req.body
    assert_instance_of WinterTc::Headers, req.headers
  end

  def test_method_is_uppercased
    req = WinterTc::Request.new("https://example.com", method: "post")
    assert_equal "POST", req.method
  end

  def test_headers_are_wrapped
    req = WinterTc::Request.new("https://example.com", headers: { "X-Foo" => "bar" })
    assert_equal "bar", req.headers.get("x-foo")
  end

  def test_body
    req = WinterTc::Request.new("https://example.com", method: "POST", body: "hello")
    assert_equal "hello", req.body
  end

  def test_clone_from_request
    original = WinterTc::Request.new("https://example.com/api", method: "POST", body: "data")
    cloned   = WinterTc::Request.new(original)
    assert_equal original.url,    cloned.url
    assert_equal original.method, cloned.method
    assert_equal original.body,   cloned.body
  end

  def test_clone_with_overrides
    original = WinterTc::Request.new("https://example.com/api", method: "POST", body: "old")
    cloned   = WinterTc::Request.new(original, method: "PUT", body: "new")
    assert_equal "PUT", cloned.method
    assert_equal "new", cloned.body
    # Original should be unchanged.
    assert_equal "POST", original.method
    assert_equal "old",  original.body
  end

  def test_invalid_input_type
    assert_raises(TypeError) { WinterTc::Request.new(42) }
  end

  def test_inspect
    req = WinterTc::Request.new("https://example.com", method: "DELETE")
    assert_includes req.inspect, "WinterTc::Request"
    assert_includes req.inspect, "DELETE"
    assert_includes req.inspect, "https://example.com"
  end
end

# ===========================================================================
# WinterTc::Response tests
# ===========================================================================
class TestResponse < Minitest::Test
  def make_response(status: 200, headers: {}, body: "", url: nil)
    WinterTc::Response.new(status: status, headers: headers, body: body, url: url)
  end

  def test_ok_for_2xx
    assert make_response(status: 200).ok
    assert make_response(status: 201).ok
    assert make_response(status: 299).ok
  end

  def test_not_ok_for_4xx_5xx
    refute make_response(status: 400).ok
    refute make_response(status: 404).ok
    refute make_response(status: 500).ok
  end

  def test_ok_alias
    assert make_response(status: 200).ok?
    refute make_response(status: 404).ok?
  end

  def test_text
    res = make_response(body: "hello world")
    assert_equal "hello world", res.text
  end

  def test_json
    res = make_response(body: JSON.generate({ key: "value" }))
    assert_equal({ "key" => "value" }, res.json)
  end

  def test_json_raises_on_invalid_json
    res = make_response(body: "not json")
    assert_raises(JSON::ParserError) { res.json }
  end

  def test_status_text_known
    assert_equal "OK",        make_response(status: 200).status_text
    assert_equal "Not Found", make_response(status: 404).status_text
    assert_equal "Created",   make_response(status: 201).status_text
  end

  def test_status_text_unknown
    assert_equal "", make_response(status: 999).status_text
  end

  def test_headers_accessible
    res = make_response(headers: { "Content-Type" => "application/json" })
    assert_equal "application/json", res.headers.get("content-type")
  end

  def test_url_attribute
    res = make_response(url: "https://example.com/api")
    assert_equal "https://example.com/api", res.url
  end

  def test_inspect
    res = make_response(status: 404)
    assert_includes res.inspect, "WinterTc::Response"
    assert_includes res.inspect, "404"
  end
end

# ===========================================================================
# WinterTc.fetch integration tests (local TCP server)
# ===========================================================================
class TestFetch < Minitest::Test
  def test_simple_get
    handler = ->(_method, _path, _req_headers, _body) do
      [200, { "Content-Type" => "text/plain" }, "hello"]
    end

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch("http://#{host}:#{port}/")
      assert_equal 200,     res.status
      assert       res.ok
      assert_equal "hello", res.text
    end
  end

  def test_post_with_body
    received_body = nil
    handler = ->(_method, _path, _req_headers, body) do
      received_body = body
      [201, { "Content-Type" => "application/json" }, JSON.generate({ created: true })]
    end

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch(
        "http://#{host}:#{port}/items",
        method: "POST",
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ name: "widget" })
      )
      assert_equal 201,              res.status
      assert_equal true,             res.json["created"]
      assert_equal '{"name":"widget"}', received_body
    end
  end

  def test_response_headers
    handler = ->(*) do
      [200, { "X-Custom-Header" => "test-value", "Content-Type" => "text/plain" }, "ok"]
    end

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch("http://#{host}:#{port}/")
      assert_equal "test-value", res.headers.get("x-custom-header")
    end
  end

  def test_404_response
    handler = ->(*) { [404, {}, "not found"] }

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch("http://#{host}:#{port}/missing")
      assert_equal 404, res.status
      refute res.ok
      assert_equal "not found", res.text
    end
  end

  def test_url_is_set_on_response
    handler = ->(*) { [200, {}, ""] }

    TestHelper.with_server(handler) do |host, port|
      url = "http://#{host}:#{port}/path"
      res = WinterTc.fetch(url)
      assert_equal url, res.url
    end
  end

  def test_fetch_with_request_object
    handler = ->(method, path, _req_headers, _body) do
      body = JSON.generate(method: method, path: path)
      [200, { "Content-Type" => "application/json" }, body]
    end

    TestHelper.with_server(handler) do |host, port|
      req = WinterTc::Request.new(
        "http://#{host}:#{port}/test",
        method: "DELETE",
      )
      res = WinterTc.fetch(req)
      assert_equal "DELETE", res.json["method"]
      assert_equal "/test",  res.json["path"]
    end
  end

  def test_custom_headers_sent_to_server
    received_headers = nil
    handler = ->(_method, _path, req_headers, _body) do
      received_headers = req_headers
      [200, {}, "ok"]
    end

    TestHelper.with_server(handler) do |host, port|
      WinterTc.fetch(
        "http://#{host}:#{port}/",
        headers: { "X-Api-Key" => "secret" }
      )
      assert_equal "secret", received_headers["x-api-key"]
    end
  end

  def test_redirect_follow
    call_count = 0
    handler = ->(_method, path, _req_headers, _body) do
      call_count += 1
      if path == "/redirect"
        [302, { "Location" => "/final" }, ""]
      else
        [200, { "Content-Type" => "text/plain" }, "final destination"]
      end
    end

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch("http://#{host}:#{port}/redirect", redirect: :follow)
      assert_equal 200, res.status
      assert_equal "final destination", res.text
      assert_equal 2, call_count
    end
  end

  def test_redirect_manual
    handler = ->(_method, path, *) do
      if path == "/redirect"
        [302, { "Location" => "/final" }, ""]
      else
        [200, {}, "should not reach here"]
      end
    end

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch("http://#{host}:#{port}/redirect", redirect: :manual)
      assert_equal 302, res.status
    end
  end

  def test_redirect_error
    handler = ->(*) { [302, { "Location" => "/final" }, ""] }

    TestHelper.with_server(handler) do |host, port|
      assert_raises(WinterTc::RedirectError) do
        WinterTc.fetch("http://#{host}:#{port}/redirect", redirect: :error)
      end
    end
  end

  def test_unsupported_method
    assert_raises(WinterTc::UnsupportedMethodError) do
      WinterTc.fetch("http://127.0.0.1:1/", method: "BREW")
    end
  end

  def test_invalid_url_scheme
    assert_raises(ArgumentError) do
      WinterTc.fetch("ftp://example.com/file")
    end
  end

  def test_json_response_helper
    handler = ->(*) do
      [200, { "Content-Type" => "application/json" }, JSON.generate([1, 2, 3])]
    end

    TestHelper.with_server(handler) do |host, port|
      res = WinterTc.fetch("http://#{host}:#{port}/")
      assert_equal [1, 2, 3], res.json
    end
  end
end
