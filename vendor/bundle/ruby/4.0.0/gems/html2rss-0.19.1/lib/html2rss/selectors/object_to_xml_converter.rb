# frozen_string_literal: true

require 'cgi'

module Html2rss
  class Selectors
    ##
    # A naive implementation of "Object to XML": converts a Ruby object to XML format.
    class ObjectToXmlConverter
      # Wrapper tags used for top-level collection conversion.
      OBJECT_TO_XML_TAGS = {
        hash: ['<object>', '</object>'],
        array: ['<array>', '</array>']
      }.freeze

      ##
      # @param object [Object] any Ruby object (Hash, Array, String, Symbol, etc.)
      def initialize(object)
        @object = object
      end

      ##
      # Converts the object to XML format.
      #
      # @return [String] representing the object in XML
      def call
        object_to_xml(@object).tap do |converted|
          Html2rss::Log.debug("#{self.class}: converted object to XML (#{converted.bytesize} bytes)")
        end
      end

      private

      def object_to_xml(object)
        case object
        when Hash
          hash_to_xml(object)
        when Array
          array_to_xml(object)
        else
          CGI.escapeHTML(object.to_s)
        end
      end

      def hash_to_xml(object)
        prefix, suffix = OBJECT_TO_XML_TAGS[:hash]
        inner_xml = object.each_with_object(+'') do |(key, value), str|
          str << "<#{key}>#{object_to_xml(value)}</#{key}>"
        end

        "#{prefix}#{inner_xml}#{suffix}"
      end

      def array_to_xml(object)
        prefix, suffix = OBJECT_TO_XML_TAGS[:array]
        inner_xml = object.each_with_object(+'') { |value, str| str << object_to_xml(value) }

        "#{prefix}#{inner_xml}#{suffix}"
      end
    end
  end
end
