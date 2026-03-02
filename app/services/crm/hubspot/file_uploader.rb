# frozen_string_literal: true

module Crm
  module Hubspot
    class FileUploader

      UPLOAD_PATH = "/files/v3/files"

      def initialize(client)
        @client = client
      end

      # Upload an UploadedFile (ActiveStorage) to HubSpot's Files API
      #
      # @param uploaded_file [UploadedFile] the Quick KYB file record
      # @param associate_to_contact [String, nil] HubSpot contact ID to associate
      # @return [Hash] { file_id: "...", name: "..." } or nil on failure
      def upload(uploaded_file, associate_to_contact: nil)
        blob = uploaded_file.file.blob

        # Download binary from ActiveStorage to a temp file
        tempfile = Tempfile.new([ blob.filename.base, ".#{blob.filename.extension}" ])
        tempfile.binmode
        blob.download { |chunk| tempfile.write(chunk) }
        tempfile.rewind

        # Build multipart form for HubSpot Files API
        options = {
          access: "PRIVATE",
          overwrite: false,
          duplicateValidationStrategy: "REJECT", # prevents duplicates matching identical names/checksums
          duplicateValidationScope: "ENTIRE_PORTAL"
        }

        folder_path = "/quick-kyb/#{uploaded_file.client_id}"

        @client.api_request(
          method: "POST",
          path: UPLOAD_PATH,
          body: nil, # multipart — handled below
          headers: {}
        )

        # The SDK doesn't natively support multipart file uploads,
        # so we use a direct Net::HTTP call via the client's token
        result = upload_via_http(tempfile, blob.filename.to_s, blob.content_type, folder_path, options)

        tempfile.close
        tempfile.unlink

        if result && result["id"]
          # Optionally associate file to a contact
          associate_file(result["id"], associate_to_contact) if associate_to_contact
          { file_id: result["id"], name: result["name"] }
        end
      rescue => e
        Rails.logger.error("[HubSpot FileUploader] #{e.message}")
        tempfile&.close
        tempfile&.unlink
        nil
      end

      private

      def upload_via_http(tempfile, filename, content_type, folder_path, options)
        uri = URI("https://api.hubapi.com#{UPLOAD_PATH}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        boundary = SecureRandom.hex(16)
        body = build_multipart_body(tempfile, filename, content_type, folder_path, options, boundary)

        request = Net::HTTP::Post.new(uri.path)
        request["Authorization"] = "Bearer #{@client.connection.access_token}"
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request.body = body

        response = http.request(request)
        JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      end

      def build_multipart_body(tempfile, filename, content_type, folder_path, options, boundary)
        parts = []

        # File part
        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
        parts << "Content-Type: #{content_type}\r\n\r\n"
        parts << tempfile.read
        parts << "\r\n"

        # Options JSON part
        file_options = options.merge(folderPath: folder_path)
        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"options\"\r\n"
        parts << "Content-Type: application/json\r\n\r\n"
        parts << file_options.to_json
        parts << "\r\n"

        # Closing boundary
        parts << "--#{boundary}--\r\n"

        parts.join
      end

      def associate_file(file_id, contact_id)
        @client.api_request(
          method: "PUT",
          path: "/crm/v3/objects/contacts/#{contact_id}/associations/files/#{file_id}/1"
        )
      rescue => e
        Rails.logger.warn("[HubSpot FileUploader] Association failed: #{e.message}")
      end

    end
  end
end
