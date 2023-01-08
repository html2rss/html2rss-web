# frozen_string_literal: true

require 'openssl'

class Roda
  ##
  # Roda's plugin namespace
  module RodaPlugins
    ##
    # Basic Auth plugin's namespace
    module BasicAuth
      def self.authorize(username, password, auth)
        given_user, given_password = auth.credentials

        secure_compare(username.to_s, given_user) & secure_compare(password.to_s, given_password)
      end

      def self.secure_compare(left, right)
        left.bytesize == right.bytesize && OpenSSL.fixed_length_secure_compare(left, right)
      end

      ##
      # Methods here become instance methods in the roda application.
      module InstanceMethods
        def basic_auth(realm:, username:, password:)
          raise ArgumentError, 'realm must not be a blank string' if realm.to_s.strip == ''

          response.headers['WWW-Authenticate'] = "Basic realm=#{realm}"

          auth = Rack::Auth::Basic::Request.new(env)

          return if auth.provided? && Roda::RodaPlugins::BasicAuth.authorize(username, password, auth)

          response.status = 401
          request.halt response.finish
        end
      end
    end

    register_plugin(:basic_auth, BasicAuth)
  end
end
