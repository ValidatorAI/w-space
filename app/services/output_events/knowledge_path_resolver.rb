module OutputEvents
  class KnowledgePathResolver
    KNOWLEDGE_TARGET_SEGMENTS = {
      "ProjectKnowledgeItem" => "items",
      "ProjectExternalAsset" => "external-assets",
      "ProjectDirectoryItem" => "directory-items",
      "ProjectObsidianNote" => "obsidian-notes",
      "ProjectKnowledgeActivity" => "activities",
      "ProjectAdr" => "adrs"
    }.freeze

    KNOWLEDGE_DATA_SEGMENTS = {
      "knowledge_item_id" => "items",
      "external_asset_id" => "external-assets",
      "directory_item_id" => "directory-items",
      "obsidian_note_id" => "obsidian-notes",
      "knowledge_activity_id" => "activities",
      "adr_id" => "adrs"
    }.freeze

    class << self
      def resolve(event_type:, event_id:, target_type:, data:)
        payload_data = (data || {}).deep_stringify_keys
        company_id = resolve_company_id
        return if company_id.blank?

        project_id = infer_project_id(event_id: event_id, target_type: target_type, data: payload_data)
        paths = explicit_paths(company_id: company_id, project_id: project_id, event_id: event_id, target_type: target_type, data: payload_data)

        if paths.empty? && project_id.present?
          paths << knowledge_root_path(company_id, project_id)
        end

        paths = paths.compact_blank.map(&:to_s).uniq
        return if paths.empty?

        format_block(paths)
      end

      private

      def resolve_company_id
        Current.account&.id || Account.first&.id
      end

      def infer_project_id(event_id:, target_type:, data:)
        return data["project_id"] if data["project_id"].present?

        case target_type
        when "Project"
          event_id
        when "Room"
          Room.find_by(id: event_id)&.project_id
        when "Message"
          message_project_id(event_id, data["room_id"])
        when "ApprovalRequest"
          approval_request_project_id(event_id, data)
        else
          generic_project_id(event_id, target_type)
        end
      end

      def explicit_paths(company_id:, project_id:, event_id:, target_type:, data:)
        paths = []

        segment = KNOWLEDGE_TARGET_SEGMENTS[target_type]
        if segment.present? && project_id.present? && event_id.present?
          paths << knowledge_subdomain_path(company_id, project_id, segment, event_id)
        end

        KNOWLEDGE_DATA_SEGMENTS.each do |id_key, subdomain|
          next if data[id_key].blank? || project_id.blank?

          paths << knowledge_subdomain_path(company_id, project_id, subdomain, data[id_key])
        end

        paths
      end

      def message_project_id(message_id, room_id)
        room_from_message = Message.includes(:room).find_by(id: message_id)&.room_id
        Room.find_by(id: room_from_message || room_id)&.project_id
      end

      def approval_request_project_id(event_id, data)
        approval_request = ApprovalRequest.find_by(id: event_id)

        room_id = data["room_id"] || approval_request&.room_id
        room_project_id = Room.find_by(id: room_id)&.project_id
        return room_project_id if room_project_id.present?

        message_id = data["message_id"] || approval_request&.message_id
        message_project_id = Message.includes(:room).find_by(id: message_id)&.room&.project_id
        return message_project_id if message_project_id.present?

        adr_id = data["adr_id"]
        ProjectAdr.find_by(id: adr_id)&.project_id
      end

      def generic_project_id(event_id, target_type)
        klass = target_type.to_s.safe_constantize
        return unless klass && klass < ApplicationRecord

        record = klass.find_by(id: event_id)
        return unless record.respond_to?(:project_id)

        record.project_id
      end

      def knowledge_root_path(company_id, project_id)
        "/company/#{company_id}/projects/#{project_id}/knowledge"
      end

      def knowledge_subdomain_path(company_id, project_id, subdomain, entity_id)
        "/company/#{company_id}/projects/#{project_id}/knowledge/#{subdomain}/#{entity_id}"
      end

      def format_block(paths)
        [
          "<knowledge_path>",
          *paths.map { |path| "- #{path}" },
          "</knowledge_path>"
        ].join("\n")
      end
    end
  end
end