class ProjectTodo < ApplicationRecord
  attr_accessor :event_actor

  belongs_to :project

  validates :title, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :pending, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }

  after_update_commit :record_completion_event, if: :saved_change_to_completed?

  def toggle_completed!
    self.event_actor ||= Current.user if defined?(Current) && Current.respond_to?(:user) && Current.user.present?

    if completed?
      update!(completed: false, completed_at: nil)
    else
      update!(completed: true, completed_at: Time.current)
    end
  end

  private

  def record_completion_event
    OutputEvents::Recorder.record(
      event_type: completed? ? "project_todo_completed" : "project_todo_reopened",
      event_id: id,
      actor: event_actor,
      target_type: "ProjectTodo",
      data: { "project_id" => project_id }
    )
  end
end
