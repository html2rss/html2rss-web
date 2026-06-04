# frozen_string_literal: true

module Html2rss
  ##
  # Shared anti-bot/interstitial signatures used by request and auto-source flows.
  #
  # This module centralizes signature matching so request-time guards and
  # auto-source surface classification stay consistent.
  module BlockedSurface
    # Known interstitial fingerprints used to detect blocked or anti-bot surfaces.
    INTERSTITIAL_SIGNATURES = [
      {
        key: :cloudflare_interstitial,
        min_matches: 2,
        patterns: [
          %r{<title>\s*just a moment\.\.\.\s*</title>}i,
          /checking your browser before accessing/i,
          /please (?:enable|turn on) javascript and cookies/i,
          %r{cdn-cgi/challenge-platform}i,
          /cloudflare ray id/i
        ],
        message: 'Blocked surface detected: Cloudflare anti-bot interstitial page. ' \
                 'Retry with --strategy browserless, try a more specific public listing URL, ' \
                 'or run from an environment that can complete anti-bot checks.'
      }
    ].freeze

    ##
    # Returns the first matching interstitial signature for the provided body.
    #
    # @param body [String, nil] response body candidate
    # @return [Hash, nil] signature hash when matched, otherwise nil
    def self.interstitial_signature_for(body)
      normalized_body = normalize_body(body)
      INTERSTITIAL_SIGNATURES.find { |signature| interstitial_signature_match?(normalized_body, signature) }
    end

    ##
    # @param body [String, nil] response body candidate
    # @return [Boolean] true when body matches a known interstitial signature
    def self.interstitial?(body)
      !interstitial_signature_for(body).nil?
    end

    def self.interstitial_signature_match?(body, signature)
      min_matches = signature.fetch(:min_matches, 1)
      matches = 0

      signature.fetch(:patterns).each do |pattern|
        matches += 1 if pattern.match?(body)
        return true if matches >= min_matches
      end

      false
    end
    private_class_method :interstitial_signature_match?

    def self.normalize_body(body)
      body.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '')
    rescue Encoding::CompatibilityError, Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      body.to_s.force_encoding(Encoding::UTF_8).scrub
    end
    private_class_method :normalize_body
  end
end
