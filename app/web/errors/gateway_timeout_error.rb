# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 504 error used when downstream request/fetch times out.
    class GatewayTimeoutError < HttpError
      DEFAULT_MESSAGE = 'Gateway timeout'
      STATUS = 504
      CODE = 'GATEWAY_TIMEOUT'
    end
  end
end
