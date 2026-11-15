class AiTaskDispatcher
  def dispatch_next_pending_task!
    task = AiTask.where(dispatched: false)
      .where("dispatch_attempts IS NULL OR dispatch_attempts < ?", AiTask::MAX_DISPATCH_ATTEMPTS)
      .order(:created_at, :id)
      .find do |candidate|
        candidate.dispatchable_profile.present?
      end
    return nil if task.blank?

    profile = task.dispatchable_profile
    message = "you have new task with id #{task.id}"
    payload = { messages: [{ role: "user", content: message }] }

    hermes_client = Hermes::Client.new
    hermes_client.chat_completions(payload, profile: profile)
    task.update!(dispatched: true, finished: false, dispatch_attempts: 0, dispatch_error: nil)
    task
  rescue StandardError => e
    Rails.logger.warn("[AiTaskDispatcher] Failed to dispatch task #{task&.id}: #{e.class}: #{e.message}")
    task&.mark_dispatch_failed!(e.message)
    nil
  end
end
