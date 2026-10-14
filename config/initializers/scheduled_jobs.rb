# Scheduled jobs for MCP Agent Chat
#
# These jobs should be run on a schedule using your preferred job scheduler.
# Examples for different schedulers:
#
# == Cron (using whenever gem or system cron) ==
#
#   # Every minute - check agent presence
#   * * * * * cd /path/to/app && bin/rails runner "AgentPresenceCheckJob.perform_later"
#
#   # Every 5 minutes - cleanup expired reservations
#   */5 * * * * cd /path/to/app && bin/rails runner "FileReservationCleanupJob.perform_later"
#
#   # Every minute - reconcile stale event dispatches & query Hermes health
#   * * * * * cd /path/to/app && bin/rails runner "OutputEvents::ReconcileDispatchesJob.perform_later"
#
# == Resque Scheduler ==
#
#   # config/resque_schedule.yml
#   agent_presence_check:
#     cron: "* * * * *"
#     class: AgentPresenceCheckJob
#     queue: default
#     description: "Check and update agent presence status"
#
#   file_reservation_cleanup:
#     cron: "*/5 * * * *"
#     class: FileReservationCleanupJob
#     queue: default
#     description: "Cleanup expired file reservations"
#
#   output_events_reconcile_dispatches:
#     cron: "* * * * *"
#     class: OutputEvents::ReconcileDispatchesJob
#     queue: default
#     description: "Reconcile stale output event dispatch groups and query Hermes status"
#
# == Solid Queue (Rails 8+) ==
#
#   # config/recurring.yml
#   agent_presence_check:
#     schedule: every minute
#     class: AgentPresenceCheckJob
#
#   file_reservation_cleanup:
#     schedule: every 5 minutes
#     class: FileReservationCleanupJob
#
#   output_events_reconcile_dispatches:
#     schedule: every minute
#     class: OutputEvents::ReconcileDispatchesJob
