class CompanyStatusPeriod < ApplicationRecord
  has_many :company_status_items, -> { order(position: :asc, created_at: :asc) }, dependent: :destroy

  has_many :priorities, -> { where(category: "priorities").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"
  has_many :progress_items, -> { where(category: "progress").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"
  has_many :risks, -> { where(category: "risks").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"
  has_many :dependencies, -> { where(category: "dependencies").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"
  has_many :material_changes, -> { where(category: "changes").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"
  has_many :decisions, -> { where(category: "decisions").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"
  has_many :learnings, -> { where(category: "learnings").order(position: :asc, created_at: :asc) }, class_name: "CompanyStatusItem"

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(starts_on: :desc, created_at: :desc) }
  scope :current, -> { where(current: true) }

  def as_status_payload
    items = company_status_items.to_a

    {
      priorities: items.select { |item| item.category == "priorities" }.map(&:as_status_payload),
      progress: items.select { |item| item.category == "progress" }.map(&:as_status_payload),
      risks: items.select { |item| item.category == "risks" }.map(&:as_status_payload),
      dependencies: items.select { |item| item.category == "dependencies" }.map(&:as_status_payload),
      changes: items.select { |item| item.category == "changes" }.map(&:as_status_payload),
      decisions: ordered_decisions(items).map(&:as_status_payload),
      learnings: items.select { |item| item.category == "learnings" }.map(&:as_status_payload)
    }
  end

  private
    def ordered_decisions(items)
      decisions = items.select { |item| item.category == "decisions" }
      decisions.sort_by do |item|
        [undecided_status?(item.status) ? 0 : 1, -item.created_at.to_i]
      end.first(5)
    end

    def undecided_status?(status)
      value = status.to_s.downcase
      value.blank? || %w[pending open undecided not_decided].include?(value)
    end
end
