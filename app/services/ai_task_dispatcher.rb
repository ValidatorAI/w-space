class AiTaskDispatcher
  def dispatch_next_pending_task!
    task = AiTask.where(dispatched: false).order(:created_at, :id).first
    return nil if task.blank?

    profile = task.assigneee_profile.presence || ENV["HERMES_DEFAULT_PROFILE"].presence || Hermes.configuration.default_profile
    message = "you have new task with id #{task.id}"
    payload = { messages: [{ role: "user", content: message }] }

    hermes_client = Hermes::Client.new
    hermes_client.chat_completions(payload, profile: profile)
    task.update!(dispatched: true)
    task
  rescue StandardError => e
    Rails.logger.warn("[AiTaskDispatcher] Failed to dispatch task #{task&.id}: #{e.class}: #{e.message}")
    nil
  end
end
