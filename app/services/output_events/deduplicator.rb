require "digest"

module OutputEvents
  class Deduplicator
    MESSAGE_EVENT_TYPES = %w[message_created message_attachment_uploaded ai_question_asked].freeze
    SETTLE_DELAY = 1.5.seconds

    # Result object returned by claim
    ClaimResult = Struct.new(:claim_status, :group, :dedupe_key, keyword_init: true) do
      def claimed?
        claim_status == :claimed
      end

      def duplicate?
        claim_status == :duplicate
      end
    end

    def self.dedupe_key_for(event)
      data = (event.event_data || {}).deep_stringify_keys

      if message_family?(event.event_type, event.group_id)
        room_id = data["room_id"] || data.dig("content_payload", "room_id")
        message_id = data.dig("content_payload", "message_id") || data["message_id"] || event.event_id

        if room_id.present? && message_id.present?
          return "message:#{event.group_id}:#{room_id}:#{message_id}"
        end
      end

      canonical_json = data.keys.sort.each_with_object({}) { |k, h| h[k] = data[k] }.to_json
      hash_fragment = Digest::SHA256.hexdigest(canonical_json)[0..15]
      identity = event.event_id || event.id || "-"
      "event:#{event.event_type}:#{identity}:#{hash_fragment}"
    end

    def self.claim(event)
      key = dedupe_key_for(event)

      # Attempt atomic claim by inserting into output_event_dispatch_groups
      group = OutputEventDispatchGroup.new(
        dedupe_key: key,
        lead_output_event_id: event.id,
        status: "pending"
      )

      if group.save
        ClaimResult.new(claim_status: :claimed, group: group, dedupe_key: key)
      else
        existing_group = OutputEventDispatchGroup.find_by(dedupe_key: key)
        ClaimResult.new(claim_status: :duplicate, group: existing_group, dedupe_key: key)
      end
    rescue ActiveRecord::RecordNotUnique
      existing_group = OutputEventDispatchGroup.find_by(dedupe_key: key)
      ClaimResult.new(claim_status: :duplicate, group: existing_group, dedupe_key: key)
    end

    def self.message_family?(event_type, group_id)
      group_id.present? && MESSAGE_EVENT_TYPES.include?(event_type.to_s)
    end

    def self.key_needs_settle?(dedupe_key)
      dedupe_key.to_s.start_with?("message:")
    end
  end
end
