class ProjectObsidianNote < ApplicationRecord
  belongs_to :project

  validates :title, presence: true
  validates :html_source_type, inclusion: { in: %w[internal_file external_url] }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def tag_list
    tags.to_s.split(/[,\s]+/).map { |t| t.start_with?("#") ? t : "##{t}" }.reject(&:blank?)
  end

  def external_source?
    html_source_type == "external_url"
  end

  def internal_source?
    html_source_type == "internal_file"
  end
end
