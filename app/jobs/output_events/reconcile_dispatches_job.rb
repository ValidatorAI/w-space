module OutputEvents
  class ReconcileDispatchesJob < ApplicationJob
    queue_as :default

    DEFAULT_LOOKBACK = 15.minutes
    MIN_STALE_AGE = 30.seconds

    def perform(max_age: nil)
      lookback_window = (max_age || Hermes.configuration.event_recovery_max_age_seconds.seconds)
      cutoff = Time.current - lookback_window
      stale_threshold = Time.current - MIN_STALE_AGE

      # 1. Query Hermes Gateway health status
      hermes_client = Hermes::Client.new
      hermes_status = hermes_client.api_status_summary
      Rails.logger.info("[OutputEvents::ReconcileDispatchesJob] Hermes status: #{hermes_status.to_json}")

      # Check throttle threshold
      max_active_agents = Hermes.configuration.max_active_agents
      active_agents = hermes_status["active_agents"].to_i
      if active_agents >= max_active_agents && max_active_agents > 0
        Rails.logger.warn("[OutputEvents::ReconcileDispatchesJob] Skipping dispatch reconciliation: active_agents=#{active_agents} >= threshold=#{max_active_agents}")
        return { reconciled_count: 0, throttled: true, hermes_status: hermes_status }
      end

      # 2. Find pending or deferred groups that are stale
      stale_groups = OutputEventDispatchGroup
        .where(status: %w[pending deferred_merge_window])
        .where("created_at >= ? AND created_at <= ?", cutoff, stale_threshold)
        .order(:created_at)

      reconciled = []
      stale_groups.each do |group|
        lead_id = group.lead_output_event_id
        if lead_id.present?
          ProcessAndDispatchJob.perform_later(lead_id, stage: :dispatch, dispatch_group_id: group.id)
          reconciled << group.id
        end
      end

      # 3. Mark groups older than lookback cutoff as failed/expired
      expired_count = 0
      OutputEventDispatchGroup
        .where(status: %w[pending deferred_merge_window])
        .where("created_at < ?", cutoff)
        .find_each do |group|
          group.update!(
            status: "failed",
            result: { error: "Reconciliation expired: exceeded lookback of #{lookback_window.to_i} seconds" }.to_json
          )
          expired_count += 1
        end

      Rails.logger.info("[OutputEvents::ReconcileDispatchesJob] Reconciled #{reconciled.size} group(s), expired #{expired_count} group(s)")
      {
        reconciled_count: reconciled.size,
        reconciled_group_ids: reconciled,
        expired_count: expired_count,
        hermes_status: hermes_status
      }
    end
  end
end
