class RoomEvidence < ApplicationRecord
  belongs_to :room
  belongs_to :project_external_asset, optional: true
  belongs_to :project_knowledge_item, optional: true

  validates :room, presence: true
  validates :evidence_type, inclusion: { in: %w[external_asset knowledge_item] }, presence: true
  validate :must_have_exactly_one_target
  validate :must_belong_to_same_project

  before_validation :set_evidence_type
  before_validation :set_default_provenance_values

  validates :visibility, inclusion: { in: %w[project public private], allow_blank: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def entity
    project_external_asset || project_knowledge_item
  end

  def entity_title
    title.presence || entity&.title.presence || "Evidence item"
  end

  def display_type
    if project_external_asset
      project_external_asset.display_type
    elsif project_knowledge_item
      project_knowledge_item.display_badge
    else
      "Evidence"
    end
  end

  def display_summary
    summary.presence || entity&.summary_text.presence || entity&.meta_text.presence || "Project source"
  end

  def effective_updated_at
    source_updated_at.presence || entity&.updated_at || updated_at
  end

  def freshness_label
    return "Fresh" if effective_updated_at.blank?

    days = ((Time.current - effective_updated_at.to_time) / 1.day).floor
    case days
    when 0..7 then "Fresh"
    when 8..30 then "Recent"
    when 31..90 then "Needs review"
    else "Stale"
    end
  end

  def visibility_label
    case visibility.to_s
    when "public" then "Public"
    when "private" then "Private"
    else "Project scoped"
    end
  end

  def provenance_summary
    pieces = []
    pieces << "By #{author_name}" if author_name.present?
    pieces << "Updated #{time_ago_label} ago" if effective_updated_at.present?
    pieces << visibility_label
    pieces.join(" • ")
  end

  private
    def time_ago_label
      return "just now" if effective_updated_at.blank?

      seconds = (Time.current - effective_updated_at.to_time).to_i
      return "#{seconds} seconds" if seconds < 60

      minutes = seconds / 60
      return "#{minutes} minute#{"s" if minutes != 1}" if minutes < 60

      hours = minutes / 60
      return "#{hours} hour#{"s" if hours != 1}" if hours < 24

      days = hours / 24
      return "#{days} day#{"s" if days != 1}" if days < 30

      months = days / 30
      return "#{months} month#{"s" if months != 1}" if months < 12

      years = months / 12
      "#{years} year#{"s" if years != 1}"
    end

    def set_evidence_type
      self.evidence_type = if project_external_asset_id.present?
        "external_asset"
      elsif project_knowledge_item_id.present?
        "knowledge_item"
      end
    end

    def set_default_provenance_values
      self.visibility ||= "project"
      self.source_updated_at ||= effective_updated_at
      self.author_name ||= room&.creator&.name || "Project source"
      self.source_label ||= entity_title
    end

    def must_have_exactly_one_target
      targets = [ project_external_asset_id.present?, project_knowledge_item_id.present? ]
      return if targets.count(true) == 1

      errors.add(:base, "must link to exactly one project evidence record")
    end

    def must_belong_to_same_project
      return if room.nil? || room.project.nil?

      target_project = if project_external_asset.present?
        project_external_asset.project
      elsif project_knowledge_item.present?
        project_knowledge_item.project
      end

      return if target_project.nil? || target_project.id == room.project_id

      errors.add(:base, "must belong to the same project as the room")
    end
end
