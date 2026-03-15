# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 500 error used for unexpected internal failures.
    class InternalServerError < HttpError
    end
  end
end
