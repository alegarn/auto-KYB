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
      # @param target_type [Symbol] :contact or :company
      # @param target_id [String, nil] HubSpot object ID to associate
      # @return [Hash] { file_id: "...", name: "..." } or nil on failure
      def upload(uploaded_file, target_type: :contact, target_id: nil)
        blob = uploaded_file.file.blob

        tempfile = Tempfile.new([ blob.filename.base, ".#{blob.filename.extension}" ])
        tempfile.binmode
        blob.download { |chunk| tempfile.write(chunk) }
        tempfile.rewind

        options = {
          access: "PRIVATE",
          overwrite: false,
          duplicateValidationStrategy: "RETURN_EXISTING",
          duplicateValidationScope: "ENTIRE_PORTAL"
        }

        folder_path = "/quick-kyb/#{uploaded_file.client_id}"

        result = upload_via_http(tempfile, blob.filename.to_s, blob.content_type, folder_path, options)

        tempfile.close
        tempfile.unlink

        if result && result["id"]
          if target_id.present?
            create_note_with_attachment(result["id"], blob.filename.to_s, target_type, target_id)
          end
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

        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
        parts << "Content-Type: #{content_type}\r\n\r\n"
        parts << tempfile.read
        parts << "\r\n"

        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"options\"\r\n"
        parts << "Content-Type: application/json\r\n\r\n"
        parts << options.to_json
        parts << "\r\n"

        if folder_path.present?
          parts << "--#{boundary}\r\n"
          parts << "Content-Disposition: form-data; name=\"folderPath\"\r\n\r\n"
          parts << folder_path.to_s
          parts << "\r\n"
        end

        parts << "--#{boundary}--\r\n"
        parts.join
      end

      def create_note_with_attachment(file_id, filename, target_type, target_id)
        association_type_id = target_type.to_s == "company" ? 190 : 202

        note_body = {
          properties: {
            hs_note_body: "Original uploaded file: #{filename}",
            hs_timestamp: Time.current.utc.iso8601,
            hs_attachment_ids: file_id.to_s
          },
          associations: [
            {
              to: {
                id: target_id.to_s
              },
              types: [
                {
                  associationCategory: "HUBSPOT_DEFINED",
                  associationTypeId: association_type_id
                }
              ]
            }
          ]
        }

        note_res = @client.api_request(
          method: "POST",
          path: "/crm/v3/objects/notes",
          body: note_body
        )

        return unless note_res && note_res["id"]
      rescue => e
        Rails.logger.warn("[HubSpot FileUploader] Note Creation/Association failed: #{e.message}")
      end

    end
  end
end
