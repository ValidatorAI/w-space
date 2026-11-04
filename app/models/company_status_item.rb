class CompanyStatusItem < ApplicationRecord
  CATEGORIES = %w[
    priorities
    progress
    risks
    dependencies
    changes
    decisions
    learnings
  ].freeze

  belongs_to :company_status_period

  validates :category, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :for_category, ->(category) { where(category: category) }

  def outcome
    subtitle.presence || self[:outcome] || ""
  end

  def outcome=(val)
    if has_attribute?(:subtitle)
      self.subtitle = val
    else
      self[:outcome] = val
    end
  end

  def status_label
    self[:status]
  end

  def status_label=(val)
    self[:status] = val
  end

  def action_event_type(action:)
    base = case category.to_s
    when "priorities" then "priority"
    when "progress" then "progress"
    when "risks" then "risk"
    when "dependencies" then "dependency"
    when "changes" then "change"
    when "decisions" then "decision"
    when "learnings" then "learning"
    else "company_status_item"
    end

    suffix = case action.to_s.downcase
    when "approve", "approved" then "approved"
    when "deny", "denied" then "denied"
    when "accept", "accepted" then "accepted"
    when "reject", "rejected" then "rejected"
    when "delete", "deleted" then "deleted"
    else action.to_s.downcase
    end

    "#{base}_#{suffix}"
  end

  def record_action_event!(actor:, action:, status:)
    event_type = action_event_type(action: action)
    normalized_status = status.to_s
    payload_content = title.presence || text.presence || "#{category} item"
    payload = {
      "category" => category,
      "status" => normalized_status,
      "title" => title,
      "text" => text,
      "action" => action.to_s,
      "company_status_period_id" => company_status_period_id,
      "target_type" => "CompanyStatusItem",
      "content" => payload_content,
      "content_payload" => {
        "type" => "company_status_item_action",
        "company_status_item_id" => id,
        "category" => category,
        "status" => normalized_status,
        "action" => action.to_s,
        "company_status_period_id" => company_status_period_id
      }.compact
    }.compact

    OutputEvents::Recorder.record(
      event_type: event_type,
      event_id: id,
      actor: actor,
      target_type: "CompanyStatusItem",
      data: payload
    )
  end

  def as_status_payload
    item_title = title.presence || text.presence || subtitle.presence || ""
    item_outcome = outcome.presence || ""

    {
      id: id.to_s,
      title: item_title,
      outcome: item_outcome,
      label: item_title,
      percent: percent&.to_s,
      color: color,
      evidence: evidence,
      type: severity,
      icon: icon,
      desc: description,
      from: from_name,
      to: to_name,
      text: text.presence || item_title,
      details: {
        category: detail_category.presence || category.to_s.singularize.titleize,
        description: description,
        owner: owner,
        targetDate: target_date,
        status: status.presence || "Open",
        impact: impact,
        actions: actions || []
      }
    }
  end
end
