# Demo Migration Order (Safest First)

This plan orders migrations from non-breaking to progressively more risky changes.
It is aligned with:
- Thread modeled as room
- Project modeled as standalone entity plus group of rooms
- Minimal structure change in existing app

## Risk Levels
- Level A: Non-breaking (safe additive)
- Level B: Low-risk but behavior-sensitive
- Level C: Potentially breaking (requires backfill and staged deploy)
- Level D: Breaking (avoid in first rollout)

## Phase 1: Level A (Non-Breaking Additive Columns)

Goal: Add optional columns and defaults only. No strict constraints yet.

Suggested migration order:

1. Add project UI metadata
- Migration name example: AddDemoFieldsToProjects
- Table: projects
- Changes:
  - add column name (string, nullable)
  - add column short_code (string, nullable)
  - add column description (text, nullable)
  - add column private (boolean, default false, null false)
- Related features:
  - Create Project
  - Project Settings
  - Project Overview
- Risk: Level A

2. Add room privacy flag
- Migration name example: AddPrivateToRooms
- Table: rooms
- Changes:
  - add column private (boolean, default false, null false)
- Related features:
  - Channel privacy toggle
- Risk: Level A

3. Add user profile and preference fields
- Migration name example: AddDemoSettingsToUsers
- Table: users
- Changes:
  - add column display_name (string, nullable)
  - add column job_title (string, nullable)
  - add column timezone (string, nullable)
  - add column preferences (json or text, nullable)
- Related features:
  - User Settings
- Risk: Level A

## Phase 2: Level A (Non-Breaking New Tables)

Goal: Introduce workflow persistence tables without touching existing behavior.

4. Create approval_requests
- Migration name example: CreateApprovalRequests
- Key columns:
  - room_id, message_id, agent_id
  - request_type, payload, status
  - requested_at, resolved_at, resolved_by_id
- Related features:
  - AI approve or deny flows
- Risk: Level A

5. Create approval_request_actions
- Migration name example: CreateApprovalRequestActions
- Key columns:
  - approval_request_id
  - actor_type, actor_id
  - action, note
- Related features:
  - Approval audit trail
- Risk: Level A

6. Create attention_items
- Migration name example: CreateAttentionItems
- Key columns:
  - project_id, room_id, source_type, source_id
  - category, title, meta_text
  - overdue, ai_confirm, status
  - due_at, resolved_at, resolved_by_id
- Related features:
  - Home attention dashboard
- Risk: Level A

7. Create ai_profiles
- Migration name example: CreateAiProfiles
- Key columns:
  - profile_name, soul, bot, bot_name
  - main_model, fallback_model, cloned_from
  - editable, tool_sets_editable
- Related features:
  - AI profile modal
  - Reusable AI profile catalog
- Risk: Level A

8. Optional: create room_ai_activity_states
- Migration name example: CreateRoomAiActivityStates
- Key columns:
  - room_id, agent_id, state, started_at, updated_at
- Related features:
  - AI typing or loading indicators
- Risk: Level A
- Note:
  - Skip if you keep this state ephemeral through ActionCable only.

## Phase 3: Level B (Indexes and Light Constraints)

Goal: Improve performance and consistency while staying mostly safe.

8. Add indexes for new query paths
- Migration name example: AddIndexesForDemoWorkflows
- Examples:
  - attention_items on status, due_at, project_id
  - approval_requests on status, room_id, requested_at
  - room_ai_activity_states on room_id and updated_at
- Risk: Level B

9. Add foreign keys where missing
- Migration name example: AddForeignKeysForDemoWorkflows
- Examples:
  - approval_requests.room_id -> rooms.id
  - approval_requests.message_id -> messages.id
  - attention_items.project_id -> projects.id
- Risk: Level B
- Note:
  - Use null allowed first if old rows may exist without references.

## Phase 4: Level C (Backfill and Behavior Switch)

Goal: Move reads and writes to new schema after data is ready.

10. Backfill project name and user display fields
- Migration name example: BackfillDemoDisplayFields
- Backfill examples:
  - projects.name from projects.slug
  - users.display_name from users.name where display_name is null
- Risk: Level C

11. App rollout step (code deploy)
- Switch UI and services to read from new columns and tables.
- Keep fallback logic for one release window.
- Risk: Level C

## Phase 5: Level C to D (Only After Validation)

Goal: Enforce strict rules only after production confirms no null gaps.

12. Tighten null constraints and unique constraints
- Migration name example: EnforceDemoConstraints
- Possible changes:
  - set projects.name not null
  - set users.display_name not null
  - add unique indexes if business rules require
- Risk: Level C or D depending on data quality

13. Any renames or type replacements
- Example: replacing existing columns or enums
- Risk: Level D
- Recommendation:
  - Avoid in first and second rollout

## Practical Run Order Summary

1. AddDemoFieldsToProjects
2. AddPrivateToRooms
3. AddDemoSettingsToUsers
4. CreateApprovalRequests
5. CreateApprovalRequestActions
6. CreateAttentionItems
7. CreateAiProfiles
8. CreateRoomAiActivityStates (optional)
9. AddIndexesForDemoWorkflows
10. AddForeignKeysForDemoWorkflows
11. BackfillDemoDisplayFields
12. EnforceDemoConstraints (later)

## Deployment Safety Checklist

- Deploy additive migrations before code that depends onreatew required field, do add nullable, backfill, enforce not null as separate steps.
- Keep dual-read fallback logic for one release cycle.
- Run backfill in batches for large tables.
- Add monitoring for failed inserts and null violations before enforcing strict constraints.
