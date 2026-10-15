class RoomEvidence < ApplicationRecord
  belongs_to :room
  belongs_to :project_external_asset, optional: true
  belongs_to :project_knowledge_item, optional: true

  validates :room, presence: true
  validates :evidence_type, inclusion: { in: %w[external_asset knowledge_item] }, presence: true
  validate :must_have_exactly_one_target
  validate :must_belong_to_same_project

  before_validation :set_evidence_type

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

  private
    def set_evidence_type
      self.evidence_type = if project_external_asset_id.present?
        "external_asset"
      elsif project_knowledge_item_id.present?
        "knowledge_item"
      end
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
