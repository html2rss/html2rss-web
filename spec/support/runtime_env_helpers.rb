# frozen_string_literal: true

module RuntimeEnvHelpers
  def capture_scrubbed_runtime_env(env_overrides)
    ClimateControl.modify(preserved_runtime_env.merge(env_overrides)) do
      Html2rss::Web::RuntimeEnv.reset!
      Html2rss::Web::RuntimeEnv.capture!
      yield
    end
  ensure
    Html2rss::Web::RuntimeEnv.reset!
  end

  private

  def preserved_runtime_env
    %w[HTML2RSS_SECRET_KEY HEALTH_CHECK_TOKEN SENTRY_DSN SENTRY_ENABLE_LOGS].each_with_object({}) do |key, env|
      value = ENV.fetch(key, nil)
      env[key] = value unless value.nil?
    end
  end
end

RSpec.configure do |config|
  config.include RuntimeEnvHelpers
end
