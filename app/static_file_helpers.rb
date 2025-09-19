# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Static file handling helpers for the main App class
    module StaticFileHelpers
      module_function

      def handle_static_files(router)
        router.on do
          if router.path_info == '/'
            serve_root_path
          elsif router.path_info.start_with?('/') && !router.path_info.include?('.')
            # Only handle frontend routes that don't have file extensions
            serve_astro_files(router)
          end
        end
      end

      def serve_root_path
        index_path = 'public/frontend/index.html'
        response['Content-Type'] = 'text/html'

        if File.exist?(index_path)
          File.read(index_path)
        else
          fallback_html
        end
      end

      def fallback_html
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>html2rss-web</title>
            <link rel="stylesheet" href="/water.css">
          </head>
          <body>
            <h1>html2rss-web</h1>
            <p>Convert websites to RSS feeds</p>
            <p>API available at <code>/api/</code></p>
          </body>
          </html>
        HTML
      end

      def serve_astro_files(router)
        astro_path = "public/frontend#{router.path_info}"
        if File.exist?("#{astro_path}/index.html")
          serve_astro_file("#{astro_path}/index.html")
        elsif File.exist?(astro_path) && File.file?(astro_path)
          serve_astro_file(astro_path)
        else
          not_found_response
        end
      end

      def serve_astro_file(file_path)
        response['Content-Type'] = 'text/html'
        File.read(file_path)
      end

      ##
      # Validate and decode Base64 string safely
      # @param encoded_string [String] Base64 encoded string
      # @return [String, nil] decoded string if valid, nil if invalid
      def validate_and_decode_base64(encoded_string)
        return nil unless encoded_string.is_a?(String)
        return nil if encoded_string.empty?

        # Check if string contains only valid Base64 characters
        return nil unless encoded_string.match?(%r{\A[A-Za-z0-9+/]*={0,2}\z})

        # Attempt to decode
        Base64.decode64(encoded_string)
      rescue ArgumentError
        nil
      end
    end
  end
end
