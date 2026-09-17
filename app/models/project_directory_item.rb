class ProjectDirectoryItem < ApplicationRecord
  belongs_to :project
  belongs_to :parent, class_name: "ProjectDirectoryItem", optional: true, inverse_of: :children
  has_many :children, class_name: "ProjectDirectoryItem", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :name, presence: true
  validates :item_type, inclusion: { in: %w[directory file] }
  validate :parent_cannot_be_self

  scope :active, -> { where(active: true) }
  scope :roots, -> { where(parent_id: nil) }
  scope :directories, -> { where(item_type: "directory") }
  scope :files, -> { where(item_type: "file") }
  scope :ordered, -> { order(Arel.sql("CASE WHEN item_type = 'directory' THEN 0 ELSE 1 END"), position: :asc, name: :asc) }

  def directory?
    item_type == "directory"
  end

  def file?
    item_type == "file"
  end

  def markdown?
    file? && (name.downcase.end_with?(".md", ".markdown") || file_path.to_s.downcase.end_with?(".md", ".markdown"))
  end

  def html?
    file? && (name.downcase.end_with?(".html", ".htm") || file_path.to_s.downcase.end_with?(".html", ".htm"))
  end

  def relative_path
    return file_path if file_path.present?

    node_names = [ name ]
    curr = parent
    while curr
      node_names.unshift(curr.name)
      curr = curr.parent
    end
    node_names.join("/")
  end

  private

  def parent_cannot_be_self
    return if parent_id.blank?

    errors.add(:parent_id, "cannot reference itself") if parent_id == id
  end
end
