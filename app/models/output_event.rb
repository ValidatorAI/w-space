class OutputEvent < ApplicationRecord
  has_many :output_event_dispatch_groups, foreign_key: :lead_output_event_id, dependent: :nullify

  validates :event_type, presence: true
  validate :event_data_must_be_an_object

  private
    def event_data_must_be_an_object
      errors.add(:event_data, "must be a JSON object") unless event_data.is_a?(Hash)
    end
end