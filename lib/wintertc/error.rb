# frozen_string_literal: true

module WinterTc
  # Base class for all WinterTc errors.
  class Error < StandardError; end

  # Raised when more redirects than {WinterTc::MAX_REDIRECTS} are encountered.
  class TooManyRedirectsError < Error; end

  # Raised when a redirect is encountered and `redirect: :error` is set.
  class RedirectError < Error; end

  # Raised when an unsupported HTTP method is requested.
  class UnsupportedMethodError < Error; end
end
