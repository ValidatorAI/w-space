namespace :ai_tasks do
  desc "Dispatch the earliest undispatched task to Hermes using the assignee profile"
  task dispatch: :environment do
    AiTaskDispatchPollJob.perform_now
  end
end
