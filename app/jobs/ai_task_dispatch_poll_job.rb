class AiTaskDispatchPollJob < ApplicationJob
  queue_as :default

  def perform
    AiTaskDispatcher.new.dispatch_next_pending_task!
  end
end
