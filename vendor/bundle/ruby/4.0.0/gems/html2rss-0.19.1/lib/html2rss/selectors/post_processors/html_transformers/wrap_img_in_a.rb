# frozen_string_literal: true

module Html2rss
  class Selectors
    module PostProcessors
      module HtmlTransformers
        ##
        # Transformer that wraps <img> tags into <a> tags linking to `img.src`.
        class WrapImgInA
          ##
          # Wraps <img> tags into <a> tags that link to `img.src`.
          #
          # @param node_name [String]
          # @param node [Nokogiri::XML::Node]
          # @param _env [Hash] transformer context
          # @option _env [Object] :_reserved reserved for transformer pipeline context
          # @return [nil]
          def call(node_name:, node:, **_env)
            return unless should_process?(node_name)

            wrap_image_in_anchor(node) unless already_wrapped?(node)
          end

          # @param node_name [String] node name currently being transformed
          # @return [Boolean] whether this transformer should run for the node
          def should_process?(node_name)
            node_name == 'img'
          end

          # @param node [Nokogiri::XML::Node] node currently being transformed
          # @return [Boolean] whether the image is already wrapped in a link
          def already_wrapped?(node)
            node.parent.name == 'a'
          end

          private

          ##
          # Wraps the <img> node in an <a> tag.
          #
          # @param node [Nokogiri::XML::Node]
          # @return [nil]
          def wrap_image_in_anchor(node)
            anchor = Nokogiri::XML::Node.new('a', node.document)
            anchor['href'] = node['src']
            node.add_next_sibling(anchor)
            anchor.add_child(node.remove)
          end
        end
      end
    end
  end
end
