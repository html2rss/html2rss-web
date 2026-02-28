# frozen_string_literal: true

module Html2rss
  module Web
    module CacheTtl
      DEFAULT_SECONDS = 3600

      class << self
        def seconds_from_minutes(value, default: DEFAULT_SECONDS)
          minutes = value.to_i
          return default unless minutes.positive?

          minutes * 60
        end
      end
    end
  end
end
