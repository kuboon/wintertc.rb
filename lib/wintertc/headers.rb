# frozen_string_literal: true

module WinterTc
  # A case-insensitive map of HTTP headers, mirroring the JavaScript
  # {https://developer.mozilla.org/en-US/docs/Web/API/Headers Headers} interface.
  #
  # Header names are normalised to lowercase internally so that lookups are
  # always case-insensitive, just like the browser implementation.
  #
  # @example Basic usage
  #   headers = WinterTc::Headers.new("Content-Type" => "application/json")
  #   headers.get("content-type")   #=> "application/json"
  #   headers.has("CONTENT-TYPE")   #=> true
  #   headers.set("Accept", "text/html")
  #   headers.append("Accept", "application/xhtml+xml")
  #   headers.get("accept")         #=> "text/html, application/xhtml+xml"
  class Headers
    include Enumerable

    # Creates a new Headers object.
    #
    # @param init [Hash, Array<Array<String>>, Headers, nil]
    #   Initial headers.  Accepts a Hash (String => String), an Array of
    #   two-element [name, value] arrays, another Headers object, or nil for
    #   an empty collection.
    # @raise [TypeError] when init is not one of the accepted types
    def initialize(init = nil)
      @data = {}
      case init
      when Hash    then init.each { |k, v| set(k, v) }
      when Array   then init.each { |(k, v)| set(k, v) }
      when Headers then init.each { |k, v| @data[k] = v }
      when nil     then # empty
      else raise TypeError, "init must be a Hash, Array, Headers, or nil"
      end
    end

    # Returns the first value associated with the given header name, or +nil+
    # if the header is not present.
    #
    # @param name [String] header name (case-insensitive)
    # @return [String, nil]
    def get(name)
      @data[normalize(name)]
    end

    # Sets a header, replacing any existing value.
    #
    # @param name  [String] header name (case-insensitive)
    # @param value [String] header value
    # @return [void]
    def set(name, value)
      @data[normalize(name)] = value.to_s
      nil
    end

    # Returns +true+ if a header with the given name exists.
    #
    # @param name [String] header name (case-insensitive)
    # @return [Boolean]
    def has(name)
      @data.key?(normalize(name))
    end

    # Removes the header with the given name.
    #
    # @param name [String] header name (case-insensitive)
    # @return [void]
    def delete(name)
      @data.delete(normalize(name))
      nil
    end

    # Appends a value to an existing header.  If the header is not yet
    # present it is created.  Multiple values are joined with +", "+,
    # following the HTTP specification.
    #
    # @param name  [String] header name (case-insensitive)
    # @param value [String] value to append
    # @return [void]
    def append(name, value)
      key = normalize(name)
      if @data.key?(key)
        @data[key] = "#{@data[key]}, #{value}"
      else
        @data[key] = value.to_s
      end
      nil
    end

    # Yields each +[name, value]+ pair.  Names are in lowercase.
    #
    # @yieldparam name  [String]
    # @yieldparam value [String]
    # @return [Enumerator] if no block is given
    # @return [self]       otherwise
    def each
      return to_enum(:each) unless block_given?

      @data.each do |name, value|
        yield name, value
      end
      self
    end

    # Returns all header names (lowercase).
    #
    # @return [Array<String>]
    def keys
      @data.keys
    end

    # Returns all header values.
    #
    # @return [Array<String>]
    def values
      @data.values
    end

    # Returns a plain +Hash+ copy of all headers.
    #
    # @return [Hash{String => String}]
    def to_h
      @data.dup
    end

    # @return [String]
    def inspect
      "#<#{self.class} #{@data.inspect}>"
    end

    private

    # Normalises a header name to lowercase.
    def normalize(name)
      name.to_s.downcase
    end
  end
end
