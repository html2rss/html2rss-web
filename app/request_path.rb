# frozen_string_literal: true

module App
  ##
  # Provides helper methods to get config names by the request path.
  class RequestPath
    attr_reader :folder_name

    ##
    # @param request [Rack::Request, #path]
    def initialize(request)
      @full_path = request.path[1..]
      parts = @full_path.split('/')

      if parts.size == 1
        @name_with_ext = @full_path
      else
        @folder_name = parts[0..-2]
        @name_with_ext = parts[-1]
      end
    end

    ##
    # @return [String]
    def full_config_name
      [@folder_name, config_name].compact.join('/')
    end

    ##
    # @return [String]
    def config_name
      parts[..-2].join('.')
    end

    ##
    # @return [String]
    def extension
      parts.last
    end

    private

    def parts
      @parts ||= @name_with_ext.split('.')
    end
  end
end
