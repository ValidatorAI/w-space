class AiTaskDispatchLoop
  class << self
    def start!
      return if Rails.env.test?
      return if running?

      interval_seconds = ENV.fetch("AI_TASK_DISPATCH_INTERVAL_SECONDS", "1").to_f
      interval_seconds = 1.0 if interval_seconds <= 0

      @thread = Thread.new do
        loop do
          begin
            AiTaskDispatchPollJob.perform_now
          rescue StandardError => e
            Rails.logger.warn("[AiTaskDispatchLoop] poll cycle failed: #{e.class}: #{e.message}")
          end

          sleep interval_seconds
        end
      end

      @thread.report_on_exception = false
      @thread
    end

    def running?
      @thread.present? && @thread.alive?
    end
  end
end
