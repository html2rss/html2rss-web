# frozen_string_literal: true

class Roda
  module RodaPlugins
    module BasicAuth
      # def self.configure(app, opts = {})
      #   plugin_opts = (app.opts[:http_auth] ||= {})
      #   app.opts[:http_auth] = plugin_opts.merge(opts)
      #   app.opts[:http_auth].freeze
      # end

      # TODO: secure compare

      ##
      # ... authenticator
      module RequestMethods
        def basic_auth(&authenticator)
          raise ArgumentError, 'must be used with a block' unless authenticator

          auth = Rack::Auth::Basic::Request.new(env)

          if auth.provided? && yield(*auth.credentials)
            env['REMOTE_USER'] = auth.username
          else
            response.status = 401
            # request.block_result(instance_exec(request, &opts[:unauthorized]))
            request.halt response.finish
          end
        end
      end
    end
    register_plugin(:basic_auth, BasicAuth)
  end
end
