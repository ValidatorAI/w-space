class MessageTopic < ApplicationRecord
  belongs_to :topic
  belongs_to :message

  validates :topic, presence: true
  validates :message, presence: true
  validates :created_date, presence: true
end
