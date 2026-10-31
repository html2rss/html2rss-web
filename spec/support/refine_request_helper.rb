# frozen_string_literal: true

require 'rack/mock'

##
# Builds JSON POST requests for refine handlers under unit test.
module RefineRequestHelper
  # @param body [Hash, String]
  # @param env [Hash] extra Rack env
  # @return [Rack::Request]
  def refine_request(body, **env)
    json = body.is_a?(String) ? body : body.to_json
    env = Rack::MockRequest.env_for('/api/v1/refine/x', method: 'POST', input: json,
                                                        'CONTENT_TYPE' => 'application/json', **env)
    Rack::Request.new(env).tap { |r| r.define_singleton_method(:response) { @response ||= Rack::Response.new } }
  end
end

RSpec.configure { |config| config.include RefineRequestHelper }
