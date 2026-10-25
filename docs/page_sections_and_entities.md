# Bonfire Page / Entity Reference

## How a record gets onto a page

A record appears on a page because a controller loads a scoped collection, the model applies the relevant business filters, and the view renders that filtered set in a section-specific layout. In other words, the page is usually a filtered projection of a shared model, not a separate database table per section.

The flow is usually:
1. Controller chooses the page context: current user, project, room, or company-period.
2. Model defines the valid set: active, open, ordered, project-scoped, room-scoped, current-period, etc.
3. View groups or iterates the filtered set and renders one card, list, or summary block per section.

This is why the same record can appear in multiple sections. The page is not creating a second copy of the record; it is filtering and grouping the same underlying dataset differently.

Examples from the live app:
- Company home loads `AttentionItem.for_user(Current.user).open_items.ordered` and then groups by `category`; see [app/controllers/users/companies_controller.rb](app/controllers/users/companies_controller.rb) and [app/models/attention_item.rb](app/models/attention_item.rb).
- Project overview loads a project-scoped set of open attention items, milestones, channels, and project members; see [app/controllers/users/projects_controller.rb](app/controllers/users/projects_controller.rb).
- Room context builds a room-scoped set of pending decision requests, linked proof assets, room economics, and room participants; see [app/controllers/rooms_controller.rb](app/controllers/rooms_controller.rb).
- The UI then renders each chunk in its own section, which is why the same entity family may show up under several summaries and widgets.

## Pages

### 1. Company Home

#### 1.1 What needs your attention
- Entities rendered:
  - AttentionItem
  - User
  - Project
  - Room
- Selection logic:
  - This is the company-wide inbox, and it is built from one shared attention collection.
  - The controller starts from `AttentionItem.for_user(Current.user).open_items.ordered`, which is the base query for all open attention items in the current user’s scope.
  - `for_user(Current.user)` narrows the data to the active user/global scope; `open_items` keeps only pending/open items; `ordered` gives the app’s default sort order.
  - The controller then builds a category hash with `group_by(&:category)`, so the same filtered list is split into buckets like decisions, blockers, mentions, material changes, AI confirmation, and knowledge proposals.
  - The view then iterates `AttentionItem::CATEGORIES` and renders one card per category from `@items_by_category[cat]`.
  - A record appears here only if it is still open, belongs to the relevant user scope, and matches one of the canonical categories. This is the live “all open action items” view, not a static archive.
- Related MCP tools:
  - `attention_items` — `/mcp`
  - `decisions_waiting` — `/mcp`
  - `blockers` — `/mcp`
  - `outcomes_review` — `/mcp`
  - `mentions` — `/mcp`
  - `material_changes` — `/mcp`
  - `ai_confirm` — `/mcp`
  - `knowledge_proposals` — `/mcp`
  - `add_decisions_waiting`, `add_blockers`, `add_outcomes_review`, `add_mentions`, `add_material_changes`, `add_ai_confirm`, `add_knowledge_proposals` — `/action-mcp` or `/mcp`
- Related MCP endpoint(s):
  - `/mcp`
  - `/action-mcp`
  - `/read-mcp`

#### 1.2 Open attention / overdue / AI awaiting confirmation
- Entities rendered:
  - AttentionItem
- Selection logic:
  - These are not different records; they are different derived views over the same open attention collection.
  - `@open_count` counts all pending items.
  - `@overdue_count` counts items where `overdue == true`.
  - `@ai_count` counts items where `ai_confirm == true`.
  - The same attention item can contribute to all three numbers if it matches the relevant condition.
- Related MCP tools:
  - `attention_items`
  - `ai_confirm`
  - `decisions_waiting`
  - `blockers`
  - `outcomes_review`
  - `mentions`
  - `material_changes`
  - `knowledge_proposals`
- Related MCP endpoint(s):
  - `/mcp`

#### 1.3 Status cards and category groupings
- Entities rendered:
  - AttentionItem
- Selection logic:
  - This is the presentation layer over the same query.
  - The page loops over `AttentionItem::CATEGORIES` and renders one card per category.
  - Each card is filled by `@items_by_category[cat]`.
  - In other words, the section is logically: “show all open items, split by category, and display a card per category.”
- Related MCP tools:
  - category-specific tools defined in `AttentionItem::CATEGORIES`
- Related MCP endpoint(s):
  - `/mcp`

### 2. Company Status

#### 2.1 Current priorities & intended outcomes
- Entities rendered:
  - CompanyStatusPeriod
  - CompanyStatusItem
- Selection logic:
  - The page loads reporting periods and picks the active period or the selected period.
  - `@periods` are loaded with `CompanyStatusPeriod.includes(:company_status_items).ordered`.
  - The status payload is built per period with `as_status_payload`.
  - Only items in the current period are shown in the main dashboard.
- Related MCP tools:
  - `company_status_period`
  - `add_company_status_period`
  - `edit_company_status_period`
  - `priorities`
  - `progress`
- Related MCP endpoint(s):
  - `/mcp`
  - `/read-mcp`

#### 2.2 Progress supported by evidence
- Entities rendered:
  - CompanyStatusItem
- Selection logic:
  - `progress` items are filtered by `category = 'progress'` within the selected company-status period.
  - The view renders them in the “Progress Supported by Evidence” card.
- Related MCP tools:
  - `progress`
- Related MCP endpoint(s):
  - `/mcp`

#### 2.3 Risks & blockers
- Entities rendered:
  - CompanyStatusItem
- Selection logic:
  - `risks` items are filtered by `category = 'risks'`.
  - These are shown as risk/blocker cards in the company status page.
- Related MCP tools:
  - `risks`
- Related MCP endpoint(s):
  - `/mcp`

#### 2.4 Cross-project dependencies
- Entities rendered:
  - CompanyStatusItem
- Selection logic:
  - `dependencies` items are filtered by `category = 'dependencies'`.
- Related MCP tools:
  - `dependencies`
- Related MCP endpoint(s):
  - `/mcp`

#### 2.5 Material changes
- Entities rendered:
  - CompanyStatusItem
- Selection logic:
  - `changes` items are filtered by `category = 'changes'`.
- Related MCP tools:
  - `changes`
- Related MCP endpoint(s):
  - `/mcp`

#### 2.6 Important decisions
- Entities rendered:
  - CompanyStatusItem
- Selection logic:
  - `decisions` items are filtered by `category = 'decisions'`.
- Related MCP tools:
  - `decisions`
- Related MCP endpoint(s):
  - `/mcp`

#### 2.7 Learning that changed future work
- Entities rendered:
  - CompanyStatusItem
- Selection logic:
  - `learnings` items are filtered by `category = 'learnings'`.
- Related MCP tools:
  - `learnings`
- Related MCP endpoint(s):
  - `/mcp`

### 3. Project Overview

#### 3.1 Project summary & objectives
- Entities rendered:
  - Project
- Selection logic:
  - This is the project root record and metadata view.
  - The page renders the project description, path, slug, code, and visibility flags from `Project`.
  - It is not a list of project child records; it is the project itself with summary metadata.
- Related MCP tools:
  - `project_milestones`
  - `project_todos`
  - `project_bottlenecks`
  - `project_knowledge_items`
- Related MCP endpoint(s):
  - `/mcp`

#### 3.2 Key milestones & alignment
- Entities rendered:
  - ProjectMilestone
  - Project
- Selection logic:
  - `@project_milestones = @project.project_milestones.active.ordered`.
  - Only active milestones are rendered.
  - They are grouped under the summary card “Key Milestones & Alignment”.
- Related MCP tools:
  - `project_milestones`
  - `add_project_milestone`
  - `edit_project_milestone`
  - `delete_project_milestone`
- Related MCP endpoint(s):
  - `/mcp`

#### 3.3 Project contributors
- Entities rendered:
  - User
  - ProjectUser
  - Project
- Selection logic:
  - `@project_users = @project.users.active.without_bots.ordered`.
  - This is the human team slice of the project.
- Related MCP tools:
  - `get_projects`
  - `get_project_users`
  - `get_users`
  - `get_room_members`
  - `add_message`
- Related MCP endpoint(s):
  - `/mcp`

#### 3.4 Attached AI teammates
- Entities rendered:
  - User
  - ProjectUser
- Selection logic:
  - `@ai_teammates = @project.users.active_bots.ordered`.
  - Only bot/AI users are shown here.
- Related MCP tools:
  - `list_ai_profiles`
  - `get_ai_profile`
- Related MCP endpoint(s):
  - `/mcp`

#### 3.5 Resources & channels
- Entities rendered:
  - Room
  - Project
- Selection logic:
  - `@project_rooms = @project.rooms.without_directs.order(:name)`.
  - The page lists the main project room plus all additional rooms/channels.
  - This section is about room/channel access, not about task records themselves.
- Related MCP tools:
  - `list_rooms`
  - `search_rooms`
  - `get_room_members`
  - `add_message`
  - `approval_requests`
  - `room_context_summary`
- Related MCP endpoint(s):
  - `/mcp`

### 4. Project Status

#### 4.1 Current phase progress
- Entities rendered:
  - Project
- Selection logic:
  - This section is the summary/status header for the project, not a list of tasks.
  - The controller sets `@bottlenecks`, `@todos`, and `@knowledge_items`, then the view renders the overall progress summary plus those cards.
- Related MCP tools:
  - `project_todos`
  - `project_bottlenecks`
  - `project_knowledge_items`
- Related MCP endpoint(s):
  - `/mcp`

#### 4.2 Active bottlenecks
- Entities rendered:
  - ProjectBottleneck
  - Project
- Selection logic:
  - `@bottlenecks = @project.bottlenecks.active.ordered`.
  - Only active bottlenecks are included.
- Related MCP tools:
  - `project_bottlenecks`
  - `add_project_bottleneck`
  - `edit_project_bottleneck`
  - `delete_project_bottleneck`
- Related MCP endpoint(s):
  - `/mcp`

#### 4.3 Next steps / what should be done
- Entities rendered:
  - ProjectTodo
  - Project
- Selection logic:
  - `@todos = @project.todos.ordered`.
  - This section is the actionable work queue for the project.
- Related MCP tools:
  - `project_todos`
  - `add_project_todo`
  - `edit_project_todo`
  - `delete_project_todo`
- Related MCP endpoint(s):
  - `/mcp`

#### 4.4 Project knowledge & context
- Entities rendered:
  - ProjectKnowledgeItem
  - Project
- Selection logic:
  - `@knowledge_items = @project.knowledge_items.active.ordered`.
  - It displays the project’s active knowledge items and contextual evidence.
- Related MCP tools:
  - `project_knowledge_items`
  - `add_project_knowledge_item`
  - `edit_project_knowledge_item`
  - `delete_project_knowledge_item`
- Related MCP endpoint(s):
  - `/mcp`

### 5. Project All-Hands

#### 5.1 AI summary & key takeaways
- Entities rendered:
  - ProjectAllHandsTakeaway
  - Project
- Selection logic:
  - `@takeaways = @project.project_all_hands_takeaways.active.ordered`.
  - Only active takeaways are rendered in the main summary section.
- Related MCP tools:
  - `project_all_hands_takeaway`
  - `add_project_all_hands_takeaway`
  - `edit_project_all_hands_takeaway`
  - `delete_project_all_hands_takeaway`
- Related MCP endpoint(s):
  - `/mcp`

#### 5.2 Action items
- Entities rendered:
  - ProjectAllHandsActionItem
  - Project
- Selection logic:
  - `@action_items = @project.project_all_hands_action_items.active.ordered`.
  - These are the follow-ups from a project all-hands discussion.
- Related MCP tools:
  - `project_all_hands_action_item`
  - `add_project_all_hands_action_item`
  - `edit_project_all_hands_action_item`
  - `delete_project_all_hands_action_item`
- Related MCP endpoint(s):
  - `/mcp`

#### 5.3 Decisions logged
- Entities rendered:
  - ProjectAllHandsDecision
  - Project
- Selection logic:
  - `@decisions = @project.project_all_hands_decisions.active.ordered`.
  - They are rendered in the decision log panel only when there are active entries.
- Related MCP tools:
  - `project_all_hands_decision`
  - `add_project_all_hands_decision`
  - `edit_project_all_hands_decision`
  - `delete_project_all_hands_decision`
- Related MCP endpoint(s):
  - `/mcp`

### 6. Project Knowledge

#### 6.1 Networked notes (Obsidian sync)
- Entities rendered:
  - ProjectObsidianNote
  - Project
- Selection logic:
  - `@obsidian_notes = @project.obsidian_notes.active.ordered`.
  - `@primary_note = @obsidian_notes.first`.
  - The page shows the main note if `html_source_path` is present.
- Related MCP tools:
  - `project_obsidian_note`
  - `add_project_obsidian_note`
  - `edit_project_obsidian_note`
  - `delete_project_obsidian_note`
- Related MCP endpoint(s):
  - `/mcp`

#### 6.2 External assets & playbooks
- Entities rendered:
  - ProjectExternalAsset
  - Project
- Selection logic:
  - `@external_assets = @project.external_assets.active.ordered`.
  - These are rendered as cards with external or internal link targets.
- Related MCP tools:
  - `external_knowledge_assets`
  - `add_external_knowledge_asset`
  - `edit_external_knowledge_asset`
  - `delete_external_knowledge_asset`
- Related MCP endpoint(s):
  - `/mcp`

#### 6.3 Decision records
- Entities rendered:
  - ProjectAdr
  - Project
- Selection logic:
  - `@adrs = @project.adrs.active.ordered`.
  - These are shown as ADR rows, including identifier, title, date, and status.
- Related MCP tools:
  - `project_decision_records`
  - `add_project_decision_record`
  - `edit_project_decision_record`
  - `delete_project_decision_record`
- Related MCP endpoint(s):
  - `/mcp`

#### 6.4 Directory explorer
- Entities rendered:
  - ProjectDirectoryItem
  - Project
- Selection logic:
  - The tree is built with `ProjectKnowledge.directory_tree(@project)`.
  - This is not a raw file listing; it is a project knowledge tree derived from `directory_items`.
- Related MCP tools:
  - `tree_based_project_directory_data`
  - `add_tree_based_project_directory_item`
  - `edit_tree_based_project_directory_item`
  - `delete_tree_based_project_directory_item`
- Related MCP endpoint(s):
  - `/mcp`

#### 6.5 Recent knowledge activity
- Entities rendered:
  - ProjectKnowledgeActivity
  - Project
- Selection logic:
  - `@knowledge_activities = @project.knowledge_activities.active.ordered`.
  - These are the project’s recent knowledge events.
- Related MCP tools:
  - `knowledge_activity_log`
  - `add_knowledge_activity_log`
  - `edit_knowledge_activity_log`
  - `delete_knowledge_activity_log`
- Related MCP endpoint(s):
  - `/mcp`

### 7. Room context / room decisions / room artifacts / room itself

#### 7.1 Room context
- Entities rendered:
  - Room
  - Project
  - Membership
  - User
  - ApprovalRequest
  - DecisionRoomEconomics
  - RoomEvidence
  - ProjectKnowledgeItem
  - ProjectExternalAsset
- Selection logic:
  - `@room_project = @room.project || @room.parent&.project`.
  - `@open_decision_requests` are approval requests for this room with `request_type = "decision"` and `status = :pending`.
  - `@room_economics` is the last `DecisionRoomEconomics` row for the room.
  - `@artifact_assets` and `@artifact_knowledge_items` are populated from `RoomEvidence` links if present, otherwise from the room’s project-level assets/knowledge.
  - `@room_outcome` comes from the project description or the first relevant knowledge item.
- Related MCP tools:
  - `room_context_summary`
  - `room_decision_context`
  - `room_evidence`
  - `room_economics`
  - `approval_requests`
  - `get_room_members`
- Related MCP endpoint(s):
  - `/mcp`

#### 7.2 Room decisions
- Entities rendered:
  - ApprovalRequest
  - DecisionRoom
  - ProjectAdr
- Selection logic:
  - Room decisions are only pending room approval requests or linked decision records.
  - `@open_decision_requests = decision_requests_scope.where(status: :pending).limit(5)`.
  - `@recent_decision_records = @room_project.adrs.active.ordered.limit(5)`.
- Related MCP tools:
  - `room_decision_context`
  - `approval_requests`
  - `add_approval_request`
  - `edit_approval_request`
  - `delete_approval_request`
- Related MCP endpoint(s):
  - `/mcp`

#### 7.3 Room artifacts
- Entities rendered:
  - RoomEvidence
  - ProjectExternalAsset
  - ProjectKnowledgeItem
- Selection logic:
  - `RoomEvidence` links a room to project knowledge or project assets.
  - If a room has direct evidence links, those are used; otherwise the room falls back to project-based assets and knowledge items.
  - These are shown as connected sources and knowledge highlights.
- Related MCP tools:
  - `room_evidence`
  - `project_knowledge_items`
  - `external_knowledge_assets`
- Related MCP endpoint(s):
  - `/mcp`

#### 7.4 Room itself
- Entities rendered:
  - Room
  - Message
  - Membership
  - User
  - Project
  - RoomHistoryTopic
  - RoomAiActivityState
- Selection logic:
  - This is the room’s main conversation and membership context.
  - `@messages = Message.where(room: @room)...` and `@room_participants` are calculated from membership data.
  - It shows the room content and the participants / context around it.
- Related MCP tools:
  - `list_rooms`
  - `search_rooms`
  - `get_room_members`
  - `add_message`
  - `delete_message`
  - `room_context_summary`
- Related MCP endpoint(s):
  - `/mcp`

## Entities

### AttentionItem
- Purpose:
  - company-home and project-level workflow queue for decisions, blockers, mentions, material changes, AI confirmation, and knowledge proposals
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer or null
  - `room_id` — integer or null
  - `user_id` — integer or null
  - `source_id` — integer or null
  - `source_type` — string or null
  - `target_id` — integer or null
  - `target_type` — string or null
  - `category` — string
  - `title` — string
  - `meta_text` — text
  - `status` — integer / enum-like value
  - `action_label` — string
  - `ai_confirm` — boolean
  - `due_at` — datetime or null
  - `overdue` — boolean
  - `resolved_at` — datetime or null
  - `resolved_by_id` — integer or null
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `attention_items` — `/mcp`
  - `decisions_waiting` — `/mcp`
  - `blockers` — `/mcp`
  - `outcomes_review` — `/mcp`
  - `mentions` — `/mcp`
  - `material_changes` — `/mcp`
  - `ai_confirm` — `/mcp`
  - `knowledge_proposals` — `/mcp`

### CompanyStatusPeriod
- Purpose:
  - reporting period for company status views
- Columns and likely types:
  - `id` — integer
  - `name` — string
  - `slug` — string
  - `starts_on` — date or null
  - `ends_on` — date or null
  - `current` — boolean
  - `position` — integer
  - `account_id` — integer or null
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `company_status_period` — `/mcp`
  - `add_company_status_period` — `/mcp`
  - `edit_company_status_period` — `/mcp`

### CompanyStatusItem
- Purpose:
  - status cards for priorities, progress, risks, dependencies, changes, decisions, and learnings
- Columns and likely types:
  - `id` — integer
  - `company_status_period_id` — integer
  - `category` — string
  - `position` — integer
  - `title` — string
  - `status` — string
  - `subtitle` — text
  - `text` — text
  - `description` — text
  - `detail_category` — string
  - `owner` — string
  - `target_date` — string
  - `impact` — text
  - `percent` — integer
  - `color` — string
  - `evidence` — text
  - `severity` — string
  - `icon` — string
  - `from_name`, `to_name` — string
  - `actions` — json array
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `priorities` — `/mcp`
  - `progress` — `/mcp`
  - `risks` — `/mcp`
  - `dependencies` — `/mcp`
  - `changes` — `/mcp`
  - `decisions` — `/mcp`
  - `learnings` — `/mcp`

### Project
- Purpose:
  - root record for project-level pages and scoping
- Columns and likely types:
  - `id` — integer
  - `name` — string
  - `path` — string
  - `slug` — string
  - `description` — text
  - `private` — boolean
  - `short_code` — string
  - `current_phase` — string
  - `progress_percent` — integer
  - `roadmap` — text
  - `recently_completed` — text
  - `budget_total`, `budget_spent` — decimal
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_milestones` — `/mcp`
  - `project_todos` — `/mcp`
  - `project_bottlenecks` — `/mcp`
  - `project_knowledge_items` — `/mcp`
  - `project_decision_records` — `/mcp`
  - `project_all_hands_takeaway` — `/mcp`
  - `project_all_hands_action_item` — `/mcp`
  - `project_all_hands_decision` — `/mcp`

### ProjectMilestone
- Purpose:
  - milestones rendered in project overview
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `description` — text
  - `icon` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_milestones` — `/mcp`
  - `add_project_milestone` — `/mcp`
  - `edit_project_milestone` — `/mcp`
  - `delete_project_milestone` — `/mcp`

### ProjectBottleneck
- Purpose:
  - blockers shown on project status
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `description` — text
  - `severity` — string
  - `resolved_at` — datetime or null
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_bottlenecks` — `/mcp`
  - `add_project_bottleneck` — `/mcp`
  - `edit_project_bottleneck` — `/mcp`
  - `delete_project_bottleneck` — `/mcp`

### ProjectTodo
- Purpose:
  - “what should be done” work queue for the project
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `meta_text` — string
  - `completed` — boolean
  - `completed_at` — datetime or null
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_todos` — `/mcp`
  - `add_project_todo` — `/mcp`
  - `edit_project_todo` — `/mcp`
  - `delete_project_todo` — `/mcp`

### ProjectKnowledgeItem
- Purpose:
  - contextual knowledge items used in project status and room artifact views
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `description` — text
  - `badge` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_knowledge_items` — `/mcp`
  - `add_project_knowledge_item` — `/mcp`
  - `edit_project_knowledge_item` — `/mcp`
  - `delete_project_knowledge_item` — `/mcp`

### ProjectAdr
- Purpose:
  - ADR / decision records surfaced in project knowledge and room decisions
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `identifier` — string
  - `title` — string
  - `status` — string
  - `decision_date` — date
  - `file_path` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_decision_records` — `/mcp`
  - `add_project_decision_record` — `/mcp`
  - `edit_project_decision_record` — `/mcp`
  - `delete_project_decision_record` — `/mcp`

### ProjectAllHandsTakeaway
- Purpose:
  - summary highlights from all-hands
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `category` — string
  - `content` — text
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_all_hands_takeaway` — `/mcp`
  - `add_project_all_hands_takeaway` — `/mcp`
  - `edit_project_all_hands_takeaway` — `/mcp`
  - `delete_project_all_hands_takeaway` — `/mcp`

### ProjectAllHandsDecision
- Purpose:
  - logged decisions in all-hands
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `badge` — string
  - `basis` — string
  - `impact` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_all_hands_decision` — `/mcp`
  - `add_project_all_hands_decision` — `/mcp`
  - `edit_project_all_hands_decision` — `/mcp`
  - `delete_project_all_hands_decision` — `/mcp`

### ProjectAllHandsActionItem
- Purpose:
  - action items produced from all-hands meetings
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `assignee_name` — string
  - `due_date` — string
  - `completed` — boolean
  - `completed_at` — datetime or null
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_all_hands_action_item` — `/mcp`
  - `add_project_all_hands_action_item` — `/mcp`
  - `edit_project_all_hands_action_item` — `/mcp`
  - `delete_project_all_hands_action_item` — `/mcp`

### ProjectExternalAsset
- Purpose:
  - external assets, docs, or playbooks surfaced in knowledge and room artifact panels
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `url` — string
  - `source_type` — string
  - `doc_type` — string
  - `icon` — string
  - `meta_text` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `external_knowledge_assets` — `/mcp`
  - `add_external_knowledge_asset` — `/mcp`
  - `edit_external_knowledge_asset` — `/mcp`
  - `delete_external_knowledge_asset` — `/mcp`

### ProjectObsidianNote
- Purpose:
  - notes synced into the knowledge surface
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `title` — string
  - `content` — text
  - `html_source_path` — string
  - `html_source_type` — string
  - `tags` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `project_obsidian_note` — `/mcp`
  - `add_project_obsidian_note` — `/mcp`
  - `edit_project_obsidian_note` — `/mcp`
  - `delete_project_obsidian_note` — `/mcp`

### ProjectDirectoryItem
- Purpose:
  - the directory tree shown in the project knowledge explorer
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `parent_id` — integer or null
  - `name` — string
  - `file_path` — string
  - `item_type` — string
  - `content` — text
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `tree_based_project_directory_data` — `/mcp`
  - `add_tree_based_project_directory_item` — `/mcp`
  - `edit_tree_based_project_directory_item` — `/mcp`
  - `delete_tree_based_project_directory_item` — `/mcp`

### ProjectKnowledgeActivity
- Purpose:
  - recent knowledge events and history of project documentation activity
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `action_text` — string
  - `actor_name` — string
  - `actor_color` — string
  - `target_path` — string
  - `target_url` — string
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `knowledge_activity_log` — `/mcp`
  - `add_knowledge_activity_log` — `/mcp`
  - `edit_knowledge_activity_log` — `/mcp`
  - `delete_knowledge_activity_log` — `/mcp`

### Room
- Purpose:
  - room-level conversation, context, and message container
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer or null
  - `parent_id` — integer or null
  - `type` — string
  - `name` — string
  - `description` — text
  - `private` — boolean
  - `archived_at` — datetime or null
  - `creator_id` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `list_rooms` — `/mcp`
  - `search_rooms` — `/mcp`
  - `get_room_members` — `/mcp`
  - `add_message` — `/mcp`
  - `room_context_summary` — `/mcp`

### ApprovalRequest
- Purpose:
  - waiting decision or approval state in a room
- Columns and likely types:
  - `id` — integer
  - `room_id` — integer
  - `message_id` — integer or null
  - `agent_id` — integer or null
  - `request_type` — string
  - `payload` — json
  - `status` — string
  - `requested_at` — datetime
  - `resolved_at` — datetime or null
  - `resolved_by_id` — integer or null
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `approval_requests` — `/mcp`
  - `get_approval_request` — `/mcp`
  - `add_approval_request` — `/mcp`
  - `edit_approval_request` — `/mcp`
  - `delete_approval_request` — `/mcp`

### RoomEvidence
- Purpose:
  - links a room to a knowledge item or external asset and records provenance
- Columns and likely types:
  - `id` — integer
  - `room_id` — integer
  - `project_knowledge_item_id` — integer or null
  - `project_external_asset_id` — integer or null
  - `title` — string
  - `summary` — string
  - `evidence_type` — string
  - `visibility` — string
  - `author_name` — string
  - `source_label` — string
  - `source_updated_at` — datetime or null
  - `provenance` — text
  - `active` — boolean
  - `position` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `room_evidence` — `/mcp`
  - `room_context_summary` — `/mcp`

### Message
- Purpose:
  - conversation content inside a room
- Columns and likely types:
  - `id` — integer
  - `room_id` — integer
  - `creator_id` — integer
  - `creator_type` — string
  - `client_message_id` — string
  - `body` or equivalent message content — text
  - `system` — boolean
  - `system_type` — string or null
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `add_message` — `/mcp`
  - `delete_message` — `/mcp`
  - `list_rooms` — `/mcp`

### DecisionRoom
- Purpose:
  - room-to-decision linkage for ADR work
- Columns and likely types:
  - `id` — integer
  - `room_id` — integer
  - `project_adr_id` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `room_decision_context` — `/mcp`
  - `project_decision_records` — `/mcp`

### DecisionRoomEconomics
- Purpose:
  - room-specific trade-off framing for decisions
- Columns and likely types:
  - `id` — integer
  - `decision_room_id` — integer
  - `risk_level` — string
  - `risk_note` — text
  - `research_effort` — integer
  - `guided_build_effort` — integer
  - `expected_learning_value` — integer
  - `summary` — text
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `room_economics` — `/mcp`
  - `room_context_summary` — `/mcp`

### User
- Purpose:
  - human or AI participant identity across project and room views
- Columns and likely types:
  - `id` — integer
  - `name` — string
  - `email_address` — string
  - `role` — string
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `get_users` — `/mcp`
  - `get_room_members` — `/mcp`
  - `list_ai_profiles` — `/mcp`
  - `get_ai_profile` — `/mcp`

### ProjectUser
- Purpose:
  - project membership association
- Columns and likely types:
  - `id` — integer
  - `project_id` — integer
  - `user_id` — integer
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `get_project_users` — `/mcp`
  - `get_users` — `/mcp`

### RoomHistoryTopic
- Purpose:
  - room topic / historical state metadata
- Columns and likely types:
  - `id` — integer
  - `room_id` — integer
  - `topic_id` — integer or null
  - `last_state` — text
  - `created_date` — datetime
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - `topics` / `room_history_topics` — `/mcp`

### RoomAiActivityState
- Purpose:
  - room AI activity state tracking
- Columns and likely types:
  - `id` — integer
  - `room_id` — integer
  - `agent_id` — integer or null
  - `state` — integer
  - `started_at` — datetime or null
  - `created_at`, `updated_at` — datetime
- Related MCP tools:
  - room activity / agent-state tools when present — `/mcp`

## MCP endpoint family
- `/mcp` — primary JSON-RPC entrypoint
- `/action-mcp` — action-oriented tool routing
- `/read-mcp` — read-only tool routing
- `/knowledge-mcp` — knowledge-oriented routing
- `/task-mcp` — task-oriented routing

This reflects the actual route definitions in Bonfire and the MCP tool grouping in the app.
