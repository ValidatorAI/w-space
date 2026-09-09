# Output Events Delivery

This document explains how Bonfire sends business events to an external endpoint using OUTPUT_EVENTS_URL.

## Environment Variables

- OUTPUT_EVENTS_URL
  - Destination URL that receives output events via HTTP POST.
  - Example: http://localhost:8031/space_events
- OUTPUT_EVENTS_TOKEN
  - Optional bearer token added as Authorization: Bearer <token>.

Configured in:
- .env

## How It Works

1. App code records a business event through OutputEvents::Recorder.
2. The event is stored in the output_events table with synced: false.
3. OutputEvents::DeliverJob is queued.
4. The job posts the event JSON payload to OUTPUT_EVENTS_URL.
5. On HTTP 2xx, event is marked synced: true.
6. On timeout/connection failure/HTTP 5xx, retries occur (up to 5 attempts).
7. On permanent failures (typically HTTP 4xx), the event remains unsynced for follow-up.

## Delivery Pipeline (Source)

- Event recording:
  - app/services/output_events/recorder.rb
- Async delivery job:
  - app/jobs/output_events/deliver_job.rb
- HTTP client and payload format:
  - app/services/output_events/delivery_client.rb
- Model validation:
  - app/models/output_event.rb

## Payload Format

Each request body is JSON:

```json
{
  "id": 123,
  "event_type": "message_created",
  "event_id": 456,
  "group_id": "ed5f2fa4-fbcb-46cf-9411-14f7a72e9f65",
  "event_data": {
    "actor": { "type": "User", "id": 1 },
    "target_type": "Message",
    "occurred_at": "2026-09-02T12:00:00Z",
    "knowledge_path": "<knowledge_path>\n- /company/1/projects/2/knowledge\n</knowledge_path>"
  },
  "created_at": "2026-09-02T12:00:00Z"
}
```

### Knowledge Path Format

- The related knowledge location is delivered as `event_data.knowledge_path`.
- The value is a single text block in this format:

```text
<knowledge_path>
- /company/[company_id]/projects/[project_id]/knowledge
- /company/[company_id]/projects/[project_id]/knowledge/adrs/[adr_id]
</knowledge_path>
```

- If multiple related knowledge locations exist, they are included as multiple `-` list lines inside the same block.
- If an event is project-backed but no artifact-specific path can be derived, Bonfire sends the project knowledge root.
- If an event is not project-backed, `knowledge_path` is omitted.

## Event Types Currently Sent

- account_settings_updated
- account_bot_access_updated
- bot_created
- bot_updated
- bot_deleted
- user_activated
- user_deactivated
- user_banned
- user_unbanned
- message_created
- message_updated
- message_deleted
- message_attachment_uploaded
- ai_question_asked
- room_created
- room_updated
- room_deleted
- room_member_added
- room_member_removed
- room_involvement_changed
- room_privacy_changed
- room_archived
- room_unarchived
- direct_conversation_created
- project_created
- project_updated
- project_deleted
- project_archived
- project_unarchived
- project_member_added
- project_member_removed
- project_first_joined
- all_hands_action_item_completed
- all_hands_action_item_reopened
- project_todo_completed
- project_todo_reopened
- approval_request_approved
- approval_request_confirmed
- approval_request_denied
- approval_request_canceled
- decision_approved

## Operational Notes

- If OUTPUT_EVENTS_URL is not set, delivery is skipped and a warning is logged.
- id can be used as an idempotency key on the receiver side.
- group_id correlates multiple events from one compound action.
- Events are delivered asynchronously and may arrive shortly after the originating action.

## Related Docs

- README.md
- docs/API_REFERENCE.md
