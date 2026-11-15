class ProjectExternalAsset < ApplicationRecord
  PLACEHOLDER_HOSTS = %w[localhost 127.0.0.1 0.0.0.0 example.invalid].freeze

  belongs_to :project
  has_many :room_evidences, dependent: :destroy
  has_many :rooms, through: :room_evidences

  validates :title, presence: true, length: { maximum: 255 }
  validates :url, presence: true
  validates :source_type, inclusion: { in: %w[internal_file external_url] }
  validate :url_must_be_valid_for_source_type

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

  def room_summary_for(room)
    room_evidences.where(room: room).order(:created_at).last&.summary.presence || meta_text.to_s.strip.presence || "Project source"
  end

  def room_provenance_for(room)
    room_evidences.where(room: room).order(:created_at).last
  end

  private

  def url_must_be_valid_for_source_type
    return if url.blank?
    return if source_type == "internal_file"

    begin
      parsed = URI.parse(url)
    rescue URI::InvalidURIError
      errors.add(:url, "must be a valid http or https URL")
      return
    end

    unless %w[http https].include?(parsed.scheme.to_s.downcase)
      errors.add(:url, "must be a valid http or https URL")
      return
    end

    host = parsed.host.to_s.downcase
    if host.blank? || placeholder_host?(host)
      errors.add(:url, "must not use a placeholder or dead domain")
    end
  end

  def placeholder_host?(host)
    normalized = host.sub(/^www\./, "")
    PLACEHOLDER_HOSTS.include?(normalized) || normalized.end_with?(".example.invalid") || normalized.end_with?(".localhost")
  end
end
