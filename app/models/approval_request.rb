class ApprovalRequest < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :room, optional: true
  belongs_to :message, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true
  has_many :approval_request_actions, dependent: :delete_all

  enum :status, { pending: 0, approved: 1, denied: 2, canceled: 3 }, default: :pending

  validates :request_type, length: { maximum: 100 }, allow_blank: true
  validate :payload_must_be_object

  before_create -> { self.requested_at ||= Time.current }

  scope :open_requests, -> { where(status: :pending) }
  scope :resolved,      -> { where.not(resolved_at: nil) }
  scope :recent,        -> { order(requested_at: :desc, created_at: :desc) }

  def decision_text
    return unless payload.is_a?(Hash)

    payload["decision"] || payload["title"] || payload["summary"] || payload["text"]
  end

  def review_title
    return request_type.to_s.humanize if payload.blank?

    decision_text.presence || (payload.is_a?(Hash) ? payload["title"].presence : nil) || request_type.to_s.humanize
  end

  def review_summary
    return unless payload.is_a?(Hash)

    payload["summary"] || payload["rationale"] || payload["description"] || payload["reason"] || payload["text"] || payload["decision"]
  end

  def review_options
    return [] unless payload.is_a?(Hash)

    options = payload["options"]

    case options
    when Array
      options.filter_map do |option|
        normalize_option(option)
      end
    when Hash
      option_entries = []
      if options["option_a"].present? || options["a"].present?
        option_entries << { label: "Option A", value: options["option_a"] || options["a"] }
      end
      if options["option_b"].present? || options["b"].present?
        option_entries << { label: "Option B", value: options["option_b"] || options["b"] }
      end
      option_entries
    else
      []
    end
  end

  def review_owner_name
    room&.creator&.name.presence || "Room owner"
  end

  def approve!(actor = Current.user, note: nil)
    record_transition!(new_status: :approved, action: "approve", actor: actor, note: note)
  end

  def confirm!(actor = Current.user, note: nil)
    record_transition!(new_status: :approved, action: "confirm", actor: actor, note: note)
  end

  def deny!(actor = Current.user, note: nil)
    record_transition!(new_status: :denied, action: "deny", actor: actor, note: note)
  end

  def cancel!(actor = Current.user, note: nil)
    record_transition!(new_status: :canceled, action: "cancel", actor: actor, note: note)
  end

  def broadcast_replacement
    return unless room.present?

    broadcast_replace_to room, :messages,
      target: dom_id(self),
      partial: "approval_requests/card",
      locals: { approval_request: self }
  end

  private

  def record_transition!(new_status:, action:, actor:, note:)
    decision_adr = nil
    transaction do
      update!(
        status: new_status,
        resolved_at: Time.current,
        resolved_by: actor.is_a?(User) ? actor : nil
      )
      approval_request_actions.create!(
        actor: actor,
        action: action,
        note: note
      )
      resolve_linked_attention_items!(actor)
      decision_adr = record_decision_if_applicable! if new_status == :approved
    end
    broadcast_replacement
    record_output_event(action, actor, decision_adr)
  end

  def resolve_linked_attention_items!(actor)
    items = AttentionItem.where(source_type: "ApprovalRequest", source_id: id)
    if message.present?
      items = items.or(AttentionItem.where(source_type: "Message", source_id: message_id))
    end
    items.open_items.find_each do |item|
      item.resolve!(actor.is_a?(User) ? actor : nil)
    end
  end

  def record_decision_if_applicable!
    return unless request_type == "decision" || (payload.is_a?(Hash) && payload["decision"].present?)

    project = room&.project
    return unless project.present?

    title = decision_text.presence || "Decision from #{room.name}"
    identifier = "ADR-#{Time.current.strftime('%Y%m%d%H%M%S')}"

    decision_adr = ProjectAdr.create!(
      project: project,
      identifier: identifier,
      title: title.to_s.truncate(255),
      status: "accepted",
      decision_date: Date.current
    )

    if room.present?
      DecisionRoom.find_or_create_by!(room: room, project_adr: decision_adr)
    end

    decision_adr
  rescue StandardError => e
    Rails.logger.error("Failed to auto-record decision from approval request #{id}: #{e.message}")
    nil
  end

  def record_output_event(action, actor, decision_adr)
    event_type = if decision_adr.present?
      "decision_approved"
    else
      {
        "approve" => "approval_request_approved",
        "confirm" => "approval_request_confirmed",
        "deny" => "approval_request_denied",
        "cancel" => "approval_request_canceled"
      }.fetch(action)
    end

    OutputEvents::Recorder.record(
      event_type: event_type,
      event_id: id,
      actor: actor,
      target_type: "ApprovalRequest",
      data: {
        "request_type" => request_type,
        "room_id" => room_id,
        "message_id" => message_id,
        "status" => status,
        "approval_request_action" => action,
        "adr_id" => decision_adr&.id
      }.compact
    )
  end

  def payload_must_be_object
    return if payload.blank? || payload.is_a?(Hash)

    errors.add(:payload, "must be a JSON object")
  end

  def normalize_option(option)
    case option
    when Hash
      label = option["label"].presence || option["title"].presence || option["name"].presence
      value = option["value"].presence || option["decision"].presence || option["text"].presence
      return if label.blank? && value.blank?

      { label: label.presence || "Option", value: value.presence || label }
    when String
      { label: "Option", value: option }
    end
  end
end