# Output events and OUTPUT_EVENTS_URL delivery status

This list is based on the current app behavior in `app/services/output_events/recorder.rb` and the delivery documentation in `docs/OUTPUT_EVENTS_DELIVERY.md`.

Asterisk (`*`) means the event is intentionally not sent to `OUTPUT_EVENTS_URL`.

## Not sent to OUTPUT_EVENTS_URL

- `account_settings_updated` *
- `account_bot_access_updated` *
- `bot_created` *
- `bot_updated` *
- `bot_deleted` *
- `user_activated` *
- `user_deactivated` *
- `user_banned` *
- `user_unbanned` *
- `room_created` *
- `room_updated` *
- `room_deleted` *
- `room_member_added` *
- `room_member_removed` *
- `room_involvement_changed` *
- `room_privacy_changed` *
- `room_archived` *
- `room_unarchived` *
- `direct_conversation_created` *
- `project_deleted` *
- `project_archived` *
- `project_unarchived` *
- `project_member_added` *
- `project_member_removed` *
- `project_first_joined` *
- `ai_config_reset` *

## Sent to OUTPUT_EVENTS_URL

- `message_created`
- `message_updated`
- `message_deleted`
- `message_attachment_uploaded`
- `ai_question_asked`
- `approval_request_approved`
- `approval_request_confirmed`
- `approval_request_denied`
- `approval_request_canceled`
- `decision_approved`
- `decision_waiting_resolved`
- `decision_waiting_dismissed`
- `blocker_resolved`
- `blocker_dismissed`
- `risk_approved`
- `risk_denied`
- `priority_approved`
- `priority_denied`

- `project_created`
- `project_updated`
- `all_hands_action_item_completed`
- `all_hands_action_item_reopened`
- `project_todo_completed`
- `project_todo_reopened`


- `ai_setting_created` #
- `ai_setting_updated` #
- `ai_setting_deleted` #
- `mcp_created` #
- `mcp_updated` #
- `mcp_deleted` #
- `skill_created` #
- `skill_updated` #
- `skill_deleted` #
- `skill_learning_requested` #
- `ai_profile_created` #
- `ai_profile_updated` #
- `ai_profile_deleted` #

## Notes

The recorder deliberately filters the starred events before persisting and enqueueing delivery, so they are never sent to `OUTPUT_EVENTS_URL`.
