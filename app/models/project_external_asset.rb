class ProjectExternalAsset < ApplicationRecord
  belongs_to :project

  validates :title, presence: true
  validates :url, presence: true
  validates :source_type, inclusion: { in: %w[internal_file external_url] }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def external_source?
    source_type == "external_url"
  end

  def internal_source?
    source_type == "internal_file"
  end

  def display_type
    doc_type.presence || (external_source? ? "External source" : "Project file")
  end

  def display_meta
    meta = meta_text.to_s.strip
    type = display_type.to_s.strip
    return meta if meta.present? && type.present? && meta.downcase.include?(type.downcase)

    [meta.presence, type].compact.join(" • ")
  end
end
