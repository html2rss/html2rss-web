# frozen_string_literal: true

module Html2rss
  # Namespace for HTML rendering logic, used to generate rich content such as
  # images, audio, video, or embedded documents for feed descriptions.
  #
  # @example
  #   Html2rss::Rendering::ImageRenderer.new(
  #     url: "https://example.com/image.jpg",
  #     title: "Example"
  #   ).to_html
  #
  # @example
  #   Html2rss::Rendering::MediaRenderer.for(
  #     enclosure: nil,
  #     image: "https://example.com/image.jpg",
  #     title: "Example"
  #   )
  #
  # @see Html2rss::Rendering::DescriptionBuilder
  module Rendering
  end
end
