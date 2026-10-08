class Topic < ApplicationRecord
  belongs_to :project
  belongs_to :parent_topic, class_name: "Topic", optional: true, inverse_of: :child_topics
  has_many :child_topics, class_name: "Topic", foreign_key: :parent_topic_id, dependent: :nullify, inverse_of: :parent_topic

  validates :project, presence: true
  validates :name, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :need_an_action, inclusion: { in: [true, false] }
  validates :importance_level,
    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 },
    allow_nil: true
end
