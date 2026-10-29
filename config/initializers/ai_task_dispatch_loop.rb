Rails.application.config.after_initialize do
  AiTaskDispatchLoop.start!
end
