# Demo Functionalities and Database Impact

This document lists the functionalities implemented in [demo.html](demo.html), and identifies which ones require database schema changes.

## 0. Modeling Assumptions (For Minimal App Changes)

- Thread is modeled as a `room` (no separate thread table).
- Project is both:
  - a separate entity (project metadata, ownership, privacy), and
  - a group of rooms (each room belongs to one project).
- Prefer extending current entities and relationships instead of introducing parallel structures.

## 1. Functionalities Present in the Demo

## 1.1 Global App and Navigation
- Multi-view single-page interface with section switching (`Home`, `Company Status`, `Project Briefing`, `Overview`, `Status`, `All-Hands`, `Knowledge`, `Channel Feed`, `Thread Detail`, settings pages).
- Sidebar navigation for company and project-level views.
- Dynamic navigation state (`active` pills/buttons).
- Per-channel feed header updates (project tag + channel name).

## 1.2 Home (Attention Inbox)
- Action-focused attention dashboard with categories:
  - Decisions waiting
  - Blockers you can resolve
  - Outcomes requiring review
  - Mentions/review requests
  - Material changes
  - AI approvals
  - Knowledge approvals
- Real-time counters:
  - Open attention count
  - Overdue count
  - AI awaiting confirmation count
  - Per-card open count badges
- Resolve action per item (`Approve`, `Confirm`, `Mark Reviewed`, etc.) which marks item resolved in UI.
- Empty state when all attention items are resolved.

## 1.3 Company Status
- Month selector with period-based datasets (June/July/August).
- Dynamic rendering of status sections:
  - Current priorities
  - Progress with evidence
  - Risks/blockers
  - Cross-project dependencies
  - Material changes
  - Important decisions
  - Learnings
- Clickable status records opening a right-side detail drawer.
- Detail drawer includes:
  - Category
  - Title
  - Description/context
  - Owner, target date, status
  - Impact
  - Action items
- Drawer close by close button or clicking overlay backdrop.

## 1.4 Company Settings
- Organization profile fields (name, workspace URL display).
- Member directory table:
  - User info
  - Role select
  - Revoke action button
  - Invite user button
- Global AI integrations:
  - Bot cards with enable/disable checkboxes
  - Visual selected state
  - Register custom agent webhook action button
- Save workspace changes action button.

## 1.5 Project Settings
- Project details editing:
  - Name
  - Description
  - Private project toggle
- Attached AI teammates listing:
  - Bot name
  - Permissions
  - Status
  - Manage bots button
- Channel management listing:
  - Channel privacy
  - Edit/archive actions
  - Create channel button
- Danger zone:
  - Archive project
  - Delete project

## 1.6 User Settings
- Profile & identity:
  - Avatar update via file input (PNG/JPG/GIF)
  - Display name
  - Role/title
  - Timezone
- Notification preferences:
  - Desktop notifications toggle
  - Email digest toggle
- Muted channels/topics management:
  - List muted entries
  - Unmute action
  - Empty-state when no muted entries remain
- Display preferences:
  - Theme select
  - Message density select
  - Link previews toggle
- Dirty-state behavior:
  - Save applies current values and stores as saved state
  - Cancel prompts to discard unsaved changes, then restores last saved state
- Avatar preview sync between settings card and sidebar avatar.

## 1.7 Create Project
- New project form with validation (`Project Name` required).
- Project metadata capture:
  - Name
  - Short code
  - Description/objective
- Bot selection grid with selectable bot cards.
- Human team section (chips + add member action button in UI).
- Default channel selection:
  - `general`
  - optional `specifications`
  - optional `releases`
- Private project option.
- On submit:
  - Creates new project block in sidebar
  - Adds standard project sub-views (Briefing/Overview/Status/All-Hands/Knowledge)
  - Creates channels dynamically with unique channel keys
  - Pre-populates channel members (humans + selected bots)
  - Navigates to first created channel
  - Resets form and default bot selections

## 1.8 Channel Feed and Threading
- Channel feed grouped by topic blocks (Zulip-style).
- Topic click opens focused thread detail view.
- Thread navigation from both feed and sidebar thread pills.
- Documentation model: each topic/thread should be represented by a `room` record (room-as-thread model).
- Message list rendering with user and AI avatars.
- Thread action prompts in-chat:
  - Decision confirm/edit
  - Knowledge approve/deny
  - Deployment action approve/deny

## 1.9 AI Response State in Chat UI
- While AI is preparing an answer, UI should show loading/typing indicator in the active room/thread.
- Indicator states should support at least:
  - `thinking` (request accepted, AI processing)
  - `typing` (AI streaming/generating message)
  - `done` (final response completed)
- Indicator should be scoped per room/thread to avoid showing activity in unrelated conversations.

## 1.10 Channel Settings Modal
- Open via channel gear button.
- Channel settings modal with:
  - Channel name
  - Member list
  - Remove member action
  - Add user via prompt
  - Add AI teammate via prompt
  - Private channel toggle
- Channel label updates in sidebar and header when privacy changes.
- Close via close button or overlay click.

## 1.11 AI Profile Modal
- Open AI profile from AI avatars.
- Dynamic profile rendering from profile map:
  - Role
  - Description
  - Skills
  - Human-approval-required actions
- Close via close button or overlay click.

## 1.12 Knowledge and Briefing Presentation Views
- Project briefing cards for extracted context, decisions, and action items.
- Project overview metrics, milestones, contributors, and resources.
- Project status progress, bottlenecks, todos, and contextual knowledge.
- All-hands summary and decisions blocks.
- Knowledge view with:
  - Obsidian-style graph and note panel
  - External docs cards
  - ADR table
  - Directory tree mock
  - Activity feed

## 2. Database Impact Classification

Legend:
- `No DB change`: behavior can run from static/in-memory data only.
- `Update existing table(s)`: persist data by adding columns or relationships to existing core entities.
- `Add new table(s)`: requires new entity type with its own lifecycle/history.

## 2.1 Features That Need New Tables

1. Attention inbox workflow tracking
- Why: needs per-item lifecycle (open/resolved), source type, due state, ownership, and audit trail.
- Suggested new tables:
  - `attention_items`
  - `attention_item_events` (status transitions/history)

2. Company status snapshots by month
- Why: month-specific priority/progress/risk/dependency/change/decision/learning records are structured time-series data.
- Suggested new tables:
  - `company_status_periods`
  - `company_priorities`
  - `company_progress_items`
  - `company_risks`
  - `company_dependencies`
  - `company_material_changes`
  - `company_decisions`
  - `company_learnings`

3. Knowledge base structured records
- Why: ADRs, notes, external assets, and activity feed events should be queryable and versionable.
- Suggested new tables:
  - `knowledge_entries`
  - `knowledge_activities`
  - `project_adrs`
  - `external_assets`

4. AI profile catalog (if managed centrally)
- Why: bots with role/skills/approval constraints are reusable entities across workspace/projects.
- Suggested new tables:
  - `ai_profiles`
  - `mcps`
  - `tools`
  - `skills`
  - `ai_profile_mcps`
  - `ai_profile_tools`
  - `ai_profile_skills`

5. Approval workflow for AI-requested actions
- Why: approvals/denials in thread and home views require persistent decision records and auditability.
- Suggested new tables:
  - `approval_requests`
  - `approval_request_actions`

6. AI room activity state (optional but recommended)
- Why: typing/loading indicators should be durable enough for reconnects and multi-client consistency.
- Suggested new table:
  - `room_ai_activity_states` (room_id, agent_id, state, started_at, updated_at)
- Note: if ultra-minimal, this can be ephemeral via websocket presence without DB persistence.

## 2.2 Features That Need Existing Table Updates

1. User settings persistence
- Existing table likely: `users`
- Needed updates:
  - Add profile columns (`display_name`, `title`, `timezone`, possibly `avatar_url`)
  - Add preference columns (or JSON settings) for notification and UI prefs

2. Muted channels/topics
- Existing likely: `users`, `rooms`/`channels`
- Needed updates:
  - If lightweight: add a `muted_targets` JSON field on user preferences
  - Better normalized: add join table (new table) `user_mutes`
- Note: normalized solution is usually preferable.

3. Project privacy and metadata
- Existing likely: `projects`
- Needed updates:
  - `private` flag
  - `short_code`
  - richer `description` / objective fields if missing

4. Room-as-thread model (minimal structural change)
- Existing likely: `rooms`
- Needed updates:
  - Add `project_id` foreign key on `rooms` (if not already present) so each room belongs to a project
  - Add `room_kind` enum/string (for example: `channel`, `thread`) if distinction is needed in UI
  - Optionally add `parent_room_id` only if you need explicit channel->thread hierarchy

5. Channel privacy and membership management
- Existing likely: `rooms`/`channels`, membership join table
- Needed updates:
  - Add `private` visibility flag on room entity
  - Ensure membership table supports both human and AI actor types (or polymorphic member references)

6. Project-to-AI attachment
- Existing likely: `projects`, `agents` (or users/bots)
- Needed updates:
  - Add/extend join relation for assigned agents to projects with permission scopes/status

7. Role management in member directory
- Existing likely: workspace/project membership tables
- Needed updates:
  - Ensure role enum supports `Workspace Admin` and `Member`
  - Add revoke/deactivation fields (`revoked_at`, `status`) if absent

8. Avatar upload
- Existing likely: `users`
- Needed updates:
  - Add avatar attachment linkage (active storage reference or `avatar_url`)

9. AI loading indicator status (if stored on existing entities)
- Existing likely: `rooms` or a message/request table
- Needed updates:
  - Add lightweight state fields (example: `ai_state`, `ai_state_updated_at`) to avoid extra tables
  - Clear state when final AI message is persisted

## 2.3 Features That Can Stay Without DB Schema Changes (UI-Only in Demo)
- View switching/navigation behavior.
- Visual counters and temporary local state.
- Modal open/close behavior.
- Static dashboard cards/content rendering.
- Form validation only on client side.

## 3. Minimal Migration Plan (Practical Starting Point)

If implementing this demo in the current app, start with these high-value schema steps:

1. Update existing tables
- `users`: profile + preferences columns.
- `projects`: `private`, `short_code`, and metadata enhancements.
- `rooms/channels`: `private` flag.

2. Add essential new tables
- `approval_requests` + `approval_request_actions`.
- `attention_items`.

3. Then add knowledge and company-status structures
- `company_status_periods` and related item tables.
- `knowledge_entries`, `knowledge_activities`, `project_adrs`.

4. AI loading indicator implementation choice
- Minimal approach: store ephemeral indicator in websocket/presence layer (no migration).
- Durable approach: add `room_ai_activity_states` table.

This ordering enables core interactive workflows first (approval, attention, channel/project settings), then analytics and knowledge depth.
