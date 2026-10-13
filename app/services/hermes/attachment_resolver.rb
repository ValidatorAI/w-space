module Hermes
  class AttachmentResolver
    MAX_ATTACHMENTS = 5
    MAX_ATTACHMENT_BYTES = 20.megabytes

    # Resolves binary file uploads and unresolved URL summaries from event_data
    # Returns [files_hash, unresolved_attachments_array]
    # files_hash format: { "file_1" => [filename, bytes, content_type], ... }
    def self.resolve(event_data)
      files = {}
      unresolved = []
      index = 1

      candidate_rows = collect_candidate_rows(event_data)

      candidate_rows.each do |row|
        break if files.size >= MAX_ATTACHMENTS

        message_id = row["message_id"] || row["id"]
        has_attachment = row["has_attachment"] == true
        url = row["attachment_url"] || row["file_url"] || row["download_url"] || row["url"]

        message = Message.find_by(id: message_id) if message_id.present?

        if message&.attachment&.attached?
          blob = message.attachment.blob
          if blob.byte_size <= MAX_ATTACHMENT_BYTES
            filename = blob.filename.to_s
            content_type = blob.content_type || "application/octet-stream"
            bytes = message.attachment.download

            files["file_#{index}"] = [filename, bytes, content_type]
            index += 1
            next
          end
        end

        # If binary could not be attached directly, retain as unresolved attachment
        if url.present? || has_attachment
          unresolved << {
            filename: row["attachment_filename"] || row["filename"] || "attachment",
            mime_type: row["attachment_content_type"] || row["content_type"] || "application/octet-stream",
            url: url,
            message_id: message_id,
            room_id: row["room_id"]
          }
        end
      end

      [files, unresolved]
    end

    def self.collect_candidate_rows(data)
      rows = []
      walk(data, rows)
      rows
    end
    private_class_method :collect_candidate_rows

    def self.walk(value, rows)
      if value.is_a?(Hash)
        rows << value if value.key?("attachment_url") || value.key?("has_attachment") || value.key?("file") || value["type"] == "file"
        value.each_value { |v| walk(v, rows) }
      elsif value.is_a?(Array)
        value.each { |v| walk(v, rows) }
      end
    end
    private_class_method :walk
  end
end
