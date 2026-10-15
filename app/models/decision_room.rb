class DecisionRoom < ApplicationRecord
  belongs_to :room
  belongs_to :project_adr

  validates :room, presence: true
  validates :project_adr, presence: true
  validates :room_id, uniqueness: { scope: :project_adr_id }
  validate :must_belong_to_same_project

  private
    def must_belong_to_same_project
      return if room.nil? || project_adr.nil?
      return if room.project_id == project_adr.project_id

      errors.add(:base, "must belong to the same project")
    end
end
