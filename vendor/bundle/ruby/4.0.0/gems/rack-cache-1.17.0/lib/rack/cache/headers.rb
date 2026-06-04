module Rack::Cache
  begin
    # For `Rack::Headers` (Rack 3+):
    require "rack/headers"
    Headers = ::Rack::Headers
    def self.Headers(headers)
      Headers[headers]
    end
  rescue LoadError
    # For `Rack::Utils::HeaderHash`:
    require "rack/utils"
    Headers = ::Rack::Utils::HeaderHash
    def self.Headers(headers)
      if headers.is_a?(Headers) && !headers.frozen?
        return headers
      else
        return Headers.new(headers)
      end
    end
  end
end
