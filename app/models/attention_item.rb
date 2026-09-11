class AttentionItem < ApplicationRecord
  CATEGORIES = %w[
    decisions_waiting
    blockers
    outcomes_review
    mentions
    material_changes
    ai_confirm
    knowledge_proposals
  ].freeze

  CATEGORY_CONFIG = {
    "decisions_waiting" => { title: "Decisions Waiting", badge_class: "orange", default_action: "Approve" },
    "blockers" => { title: "Blockers You Can Resolve", badge_class: "red", default_action: "Assign & Unblock" },
    "outcomes_review" => { title: "Outcomes Requiring Review", badge_class: "blue", default_action: "Record Result" },
    "mentions" => { title: "Mentions & Requested Reviews", badge_class: "orange", default_action: "Mark Reviewed" },
    "material_changes" => { title: "Material Changes In Your Projects", badge_class: "gray", default_action: "Acknowledge" },
    "ai_confirm" => { title: "AI Work Awaiting Confirmation", badge_class: "purple", default_action: "Approve Action" },
    "knowledge_proposals" => { title: "Knowledge Proposals Awaiting Approval", badge_class: "green", default_action: "Approve Knowledge" }
  }.freeze

  RESOLVED_EVENT_TYPES = {
    "decisions_waiting" => "decision_waiting_resolved",
    "blockers" => "blocker_resolved",
    "outcomes_review" => "outcome_review_resolved",
    "mentions" => "mention_resolved",
    "material_changes" => "material_change_resolved",
    "ai_confirm" => "ai_confirm_resolved",
    "knowledge_proposals" => "knowledge_proposal_resolved"
  }.freeze

  belongs_to :user, optional: true
  belongs_to :project, optional: true
  belongs_to :room, optional: true
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  enum :status, { pending: 0, resolved: 1, dismissed: 2 }, default: :pending

  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :title, presence: true, length: { maximum: 255 }

  scope :open_items, -> { where(status: :pending) }
  scope :resolved_items, -> { where(status: :resolved) }
  scope :overdue_items, -> { where(overdue: true) }
  scope :ai_awaiting_confirmation, -> { where(ai_confirm: true) }
  scope :for_user, ->(user) { where(user_id: [ user&.id, nil ]) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(overdue: :desc, due_at: :asc, created_at: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  def self.category_title(cat)
    CATEGORY_CONFIG.dig(cat.to_s, :title) || cat.to_s.humanize
  end

  def self.category_badge_class(cat)
    CATEGORY_CONFIG.dig(cat.to_s, :badge_class) || "gray"
  end

  def effective_action_label
    action_label.presence || CATEGORY_CONFIG.dig(category.to_s, :default_action) || "Resolve"
  end

  def resolved_event_type
    RESOLVED_EVENT_TYPES[category.to_s] || "attention_item_resolved"
  end

  def resolve!(user = Current.user)
    update!(
      status: :resolved,
      resolved_at: Time.current,
      resolved_by: user
    )
  end

  def dismiss!(user = Current.user)
    update!(
      status: :dismissed,
      resolved_at: Time.current,
      resolved_by: user
    )
  end
end