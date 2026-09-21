# Demo Database Plan (Table-by-Table)

This file is the database-specific companion to [docs/DEMO_FUNCTIONALITIES_DB_IMPACT.md](docs/DEMO_FUNCTIONALITIES_DB_IMPACT.md).

Scope assumptions (minimal structure change):
- Thread is a room.
- Project is both a standalone entity and a group of rooms.
- Prefer extending existing tables over introducing parallel models.

## Breaking Change Legend
- Non-breaking: safe additive change (new nullable column, new table, new index).
- Potentially breaking: can fail deploy or runtime behavior without backfill / staged rollout.
- Breaking: incompatible rename/remove/type change or new strict constraint against existing data.

## 1. Existing Tables (Change One by One)

## 1.1 projects
- Current role in app:
  - Standalone project entity (`path`, `slug`) and parent of rooms/agents.
- Proposed changes:
  - Add `name` (string) for UI display.
  - Add `short_code` (string) for project creation form.
  - Add `description` (text) for overview/settings.
  - Add `private` (boolean, default false) for access control.
- Related features:
  - Create Project
  - Project Settings
  - Project Overview
- Breaking change hint:
  - Non-breaking if added nullable (or with safe defaults).
  - Potentially breaking if you enforce `NOT NULL` immediately without backfill.

## 1.2 rooms
- Current role in app:
  - Conversation container already linked to `project_id`; used for channel/direct/project/task types.
- Proposed changes:
  - Keep thread-as-room using current table (no separate thread table).
  - Add `private` (boolean, default false) if channel privacy must be persisted separately from type.
  - Optional: add `parent_room_id` only if explicit channel -> thread hierarchy is required.
- Related features:
  - Channel Feed and Threading
  - Channel Settings (private toggle)
  - Project as group of rooms
- Breaking change hint:
  - Non-breaking for `private` as additive column.
  - Potentially breaking for `parent_room_id` if app logic assumes flat rooms and no parent references.

## 1.3 memberships
- Current role in app:
  - Polymorphic room participants (`User`/`Agent`) with involvement/unread tracking.
- Proposed changes:
  - No mandatory schema change for base demo.
  - Optional: add `role` (string/enum) if per-room role management is needed in UI.
  - Optional: add `muted` boolean if mute should not be represented by existing involvement states.
- Related features:
  - Member Directory / role controls
  - Muted channels/topics
  - Channel team management
- Breaking change hint:
  - Non-breaking for additive optional columns.
  - Potentially breaking if converting existing `involvement` semantics without migration mapping.

## 1.4 users
- Current role in app:
  - Identity, auth, status, bio; creator/participant for messages and rooms.
- Proposed changes:
  - Add `display_name` (string).
  - Add `job_title` (string).
  - Add `timezone` (string).
  - Add `preferences` (text/json) for notification + appearance toggles.
  - Avatar can stay in ActiveStorage (no column required) or add `avatar_url` if needed.
- Related features:
  - User Settings (profile, notifications, display)
  - Sidebar/user avatar sync
- Breaking change hint:
  - Non-breaking for additive columns.
  - Potentially breaking if code starts reading new fields without fallback to `name`/defaults.

## 1.5 messages
- Current role in app:
  - Core chat records, polymorphic creator, rich text body.
- Proposed changes:
  - No required schema change for current demo.
  - Optional: add `kind`/`subtype` only if decision/approval messages must be queryable without parsing body.
- Related features:
  - Thread detail prompts
  - AI approval interactions
- Breaking change hint:
  - Non-breaking if optional field only.
  - Breaking if you replace existing message rendering based on hard-required new enum values without backfill.

## 1.6 agents
- Current role in app:
  - AI teammate records per project; presence + auth token + messages.
- Proposed changes:
  - Usually no mandatory schema change for this demo.
  - Optional: add `capabilities` (text/json) and `requires_human_approval` (boolean) if profile modal must be DB-driven.
- Related features:
  - AI profile modal
  - Project attached AI teammates
- Breaking change hint:
  - Non-breaking for additive columns.

## 2. New Tables (If Feature Needs Persistence)

## 2.1 approval_requests
- Purpose:
  - Persist AI requests that need human approval/denial.
- Suggested columns:
  - `room_id`, `message_id` (source context), `agent_id`, `request_type`, `payload`, `status`, `requested_at`, `resolved_at`, `resolved_by_id`.
- Related features:
  - Approve/Deny action in thread
  - Home AI work awaiting confirmation
- Breaking change hint:
  - Non-breaking (new table).

## 2.2 approval_request_actions
- Purpose:
  - Audit log for request state transitions.
- Suggested columns:
  - `approval_request_id`, `actor_type`, `actor_id`, `action`, `note`, `created_at`.
- Related features:
  - Approval history and traceability
- Breaking change hint:
  - Non-breaking (new table).

## 2.3 attention_items
- Purpose:
  - Persist Home attention inbox items instead of in-memory UI-only cards.
- Suggested columns:
  - `project_id`, `room_id`, `source_type`, `source_id`, `category`, `title`, `meta_text`, `overdue`, `ai_confirm`, `status`, `due_at`, `resolved_at`, `resolved_by_id`.
- Related features:
  - Home attention dashboard and counters
- Breaking change hint:
  - Non-breaking (new table).

## 2.4 room_ai_activity_states (optional)
- Purpose:
  - Persist AI loading/typing indicator state per room for multi-client consistency.
- Suggested columns:
  - `room_id`, `agent_id`, `state` (`thinking|typing|done`), `started_at`, `updated_at`.
- Related features:
  - Loading/typing indicator while AI prepares answer
- Breaking change hint:
  - Non-breaking (new table).
  - Can be skipped if state is ephemeral over ActionCable/presence only.

## 2.5 ai_profiles
- Purpose:
  - Persist reusable AI profile metadata for profile modals and bot configuration.
- Suggested columns:
  - `profile_name`, `soul`, `bot`, `bot_name`, `profile_icon` (ActiveStorage attachment), `editable`, `main_model`, `fallback_model`, `cloned_from`, `tool_sets_editable`.
- Related features:
  - AI profile modal
  - Reusable bot profile catalog
- Breaking change hint:
  - Non-breaking (new table).

## 3. Recommended Minimal Sequence

1. Add only additive columns on existing tables:
- `projects`: `name`, `short_code`, `description`, `private`
- `rooms`: `private` (and only later `parent_room_id` if truly needed)
- `users`: profile + preference fields

2. Add high-value workflow tables:
- `approval_requests`
- `approval_request_actions`
- `attention_items`
- `ai_profiles`

3. Add AI loading indicator persistence only if needed:
- Use ephemeral ActionCable state first.
- Add `room_ai_activity_states` when reconnect consistency becomes necessary.

## 4. Migration Safety Notes

- Use 2-step migrations for strict constraints:
  - Step 1: add nullable column.
  - Step 2: backfill data.
  - Step 3: add `NOT NULL` / unique constraints.
- Avoid renaming/removing current columns in first rollout.
- Keep thread-as-room by reusing `rooms` to avoid structural breakage.
