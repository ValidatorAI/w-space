# W-bridge Features Catalog and Bonfire Native Porting Plan

## Executive Summary

The purpose of this document is to provide a complete, exhaustive catalog of all features, behaviors, schemas, and endpoints currently implemented in the Python/FastAPI service **W-bridge**, followed by a phased, actionable engineering plan to port and support these features natively within the **Bonfire** Ruby on Rails repository.

Currently, Bonfire and W-bridge operate in a circular HTTP loopback:
1. Bonfire records domain mutations and posts webhooks to W-bridge (`OUTPUT_EVENTS_URL` -> `/space_events`).
2. W-bridge stores, deduplicates, and merges these events, then calls Hermes (`/chat/completions`).
3. During execution, Hermes calls MCP tools hosted on W-bridge (`/action-mcp`, `/read-mcp`, `/knowledge-mcp`, `/task-mcp`).
4. W-bridge converts these tool calls into HTTP requests back against Bonfire's REST API (`/api/...`).

### Architectural Shift: Loopback to Native Platform

```
CURRENT ARCHITECTURE (Loopback via External Service):
┌──────────────┐     HTTP Webhook     ┌──────────────┐     HTTP API     ┌──────────────┐
│   Bonfire    │ ───────────────────> │   W-bridge   │ ───────────────> │    Hermes    │
│ (Rails + DB) │                      │   (Python)   │ <─────────────── │  (AI Agent)  │
└──────────────┘                      └──────────────┘                  └──────────────┘
       ▲                                     │
       └─────────────────────────────────────┘
                 HTTP REST Calls (/api/...)
                 (From W-bridge MCP Tools)


TARGET ARCHITECTURE (Unified Native Bonfire):
┌──────────────────────────────────────────────────────────────────┐
│                             Bonfire                              │
│                                                                  │
│  ┌───────────────────────┐             ┌──────────────────────┐  │     HTTP API     ┌──────────────┐
│  │ OutputEvents::Recorder│ ──(Job)───> │ OutputEvents::       │──┼────────────────> │    Hermes    │
│  └───────────────────────┘             │ ProcessAndDispatchJob│  │                  │  (AI Agent)  │
│                                        └──────────────────────┘  │ <────────────────│              │
│                                                    │             │    MCP (JSON-RPC)│              │
│                                                    ▼             │                  │              │
│  ┌────────────────────────────────────────────────────────────┐  │                  │              │
│  │ Native MCP Controller (/mcp, /action-mcp, /read-mcp, etc.) │ <┼──────────────────┘              │
│  └────────────────────────────────────────────────────────────┘  │
│                                │                                 │
│                                ▼                                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Direct ActiveRecord Models, Validations & Services         │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

By bringing all features of W-bridge directly into Bonfire:
- **Zero loopback latency**: MCP tools interact directly with ActiveRecord models and database transactions, eliminating HTTP serialization, network overhead, and duplicate auth handshakes.
- **Transactional integrity**: Tool actions run in standard database transactions with ActiveRecord validations and callbacks.
- **ActiveJob deduplication**: Event deduplication, sibling settling windows, and dispatching leverage Rails-native ActiveJob queues (SolidQueue / Resque).
- **Single persistence & observability**: All MCP call telemetry, exception logs, and dispatch states live in Bonfire's primary database.
- **Full retirement of Python W-bridge**: The standalone FastAPI application and its SQLite database are completely decommissioned.

---

## Part 1: Comprehensive Catalog of W-bridge Features

W-bridge comprises five primary subsystems:
1. **Space Event Ingestion & Deduplication Bus**
2. **Model Context Protocol (MCP) Server & Tool Registry**
3. **Agent / LLM Orchestration & Hermes Client**
4. **Data Persistence & Telemetry**
5. **Operational Utilities & Cron Lifecycle**

---

### 1. Space Event Ingestion & Deduplication Bus

#### 1.1 Webhook Endpoint (`POST /space_events`)
- **Authentication**: Requires `Authorization: Bearer <OUTPUT_EVENTS_TOKEN>`.
- **Payload Acceptance**: Ingests JSON payloads formatted as `SpaceEventInput` containing `id`, `event_type`, `event_id`, `group_id`, `event_data`, and `created_at`.
- **Persistence**: Persists every incoming event to `space_events` with internal row ID, raw payload, received timestamp, and computed deduplication key.

#### 1.2 Deduplication Engine (`bus/dedupe.py`)
Rails emits user actions as a group of individual webhooks sharing `group_id` and `event_id`. For example, sending a message that mentions a bot produces:
- `message_created` (base event)
- `message_attachment_uploaded` (if attachments are included)
- `ai_question_asked` (specifying target `bot_user_ids`)

W-bridge implements transport-level deduplication to guarantee **exactly-one dispatch per user action**:
- **Message Family Dedupe Key**:
  `message:<group_id>:<room_id>:<message_id>`
  Collapses `message_created`, `message_attachment_uploaded`, and `ai_question_asked` into a single dispatch unit.
- **Generic Event Dedupe Key**:
  `event:<event_type>:<rails_event_id>:<sha256(event_data)[:16]>`
  Used for distinct non-message events (account updates, room changes), preventing duplicate execution upon webhook retries.
- **Atomic Dedupe Claiming**:
  Claims the dispatch group by inserting into `space_event_dispatch_groups` with a `UNIQUE` constraint on `dedupe_key`. Only the first event row to acquire the claim is queued; subsequent sibling events are marked `duplicate_merged`.
- **Settle Window (`SPACE_EVENT_MERGE_SETTLE_SECONDS = 1.5s`)**:
  When a claimed message group item is dequeued, it checks if sibling webhooks are still in flight. If the group was created less than 1.5 seconds ago, it defers dispatch until the settle window elapses so all siblings are captured.
- **Payload Merging (`merge_group_events`)**:
  Combines all stored members of the claimed group into one payload. It preserves `bot_user_ids` from `ai_question_asked` while attaching the text and metadata from `message_created`.
- **Crash Recovery (`pending_dispatch_items`)**:
  On startup or periodic reconciliation, queries `space_event_dispatch_groups` for pending or interrupted claims within `SPACE_EVENT_LEGACY_DISPATCH_LOOKBACK_SECONDS` (300s) and restores them into the execution queue.

#### 1.3 Event Queue & Dispatch Execution (`bus/queues.py`, `bus/executors.py`)
- **Queue**: Async in-memory queue (`asyncio.Queue`).
- **Execution Modes**:
  - `fire_and_forget` (background async task)
  - Synchronous awaitable dispatch
- **Attachment Pre-fetching & Multipart Preparation**:
  - Extracts attachment identifiers (`message_id`, `room_id`, `project_id`, or URLs).
  - Fetches binary attachments via Bonfire API (`/api/rooms/:room_id/messages/:message_id/attachment`) or direct HTTP URL.
  - Enforces size limit `HERMES_EVENT_MAX_ATTACHMENT_BYTES` (default 50MB) and count limit `HERMES_EVENT_MAX_ATTACHMENTS` (default 5).
  - Prepares binary multipart upload fields (`file_1`, `file_2`, etc.) for Hermes.
  - Generates fallback textual attachment summaries if prefetching is disabled or fails.
- **Result Recording**:
  Marks the dispatch group as `dispatched` or `failed`, recording the Hermes response payload or structured error details.

---

### 2. Model Context Protocol (MCP) Server Layer

W-bridge implements the Model Context Protocol over HTTP using JSON-RPC 2.0 (protocol version `2024-11-05`).

#### 2.1 Protocol Capabilities & Endpoints
- **Endpoints Exposed**:
  - `POST /action-mcp`: Hosts 94 state-mutating tools.
  - `POST /read-mcp`: Hosts 46 read-only and introspection tools.
  - `POST /knowledge-mcp`: Knowledge-focused MCP endpoint (`hello`).
  - `POST /task-mcp`: Task decomposition and estimation endpoint (`hello`).
  - `POST /mcp`: Canonical endpoint accepting all registered tools.
- **Supported Methods**:
  - `initialize`: Returns server info (`name: "w-bridge-mcp"`, `version: "1.0.0"`) and server capabilities (`{ tools: {} }`).
  - `notifications/initialized` / `initialized`: Notification acknowledgement (returns 204 or empty object).
  - `ping`: Health check returning `{}`.
  - `tools/list`: Returns JSON schema definitions, descriptions, and parameter requirements for all mounted tools.
  - `tools/call`: Executes a tool by name with provided arguments and returns `{ content: [{ type: "text", text: "..." }], isError: false }`.
- **JSON-RPC Error Compliance**:
  - `-32700`: Parse error (invalid JSON).
  - `-32600`: Invalid Request (missing JSON-RPC structure).
  - `-32601`: Method not found.
  - `-32602`: Invalid params (missing tool name or invalid arguments).
  - `-32603`: Internal execution error.

#### 2.2 Complete Tool Registry (171 Total Tools)
The registry provides 112 canonical tools and 59 convenience aliases.

##### A. Company Attention Items
- `add_ai_confirm`: Create company AI-confirm attention item.
- `add_blockers`: Create company blocker attention item.
- `add_decisions_waiting`: Create company decisions-waiting attention item.
- `add_knowledge_proposals`: Create company knowledge-proposal attention item.
- `add_material_changes`: Create company material-change attention item.
- `add_mentions`: Create company mention attention item.
- `add_outcomes_review`: Create company outcomes-review attention item.
- `ai_confirm` / `blockers` / `decisions_waiting` / `knowledge_proposals` / `material_changes` / `mentions` / `outcomes_review`: Full CRUD access using `item_id`, attributes, and `delete=true`.
- `edit_ai_confirm` / `edit_blockers` / `edit_decisions_waiting` / `edit_knowledge_proposals` / `edit_material_changes` / `edit_mentions` / `edit_outcomes_review`: Explicit update tools.
- `attention_items`: Generic attention items query and management.

##### B. Company Status Streams & Periods
- `add_company_status_period`: Create a new company status period (week, sprint, or quarter).
- `company_status_period`: Full CRUD for status periods.
- `edit_company_status_period`: Update an existing status period.
- `priorities` / `progress` / `risks` / `dependencies` / `changes` / `decisions` / `learnings`: Unified category tools managing items under a period with `item_id`, `company_status_period_id`, `project_id`, `title`, `status`, `health`, `badge`, `summary`, `details`, `owner_name`, and `delete=true`.

##### C. Project Milestones & Bottlenecks
- `add_project_milestone`, `edit_project_milestone`, `delete_project_milestone`, `project_milestones`.
- `add_project_bottleneck`, `edit_project_bottleneck`, `delete_project_bottleneck`, `project_bottlenecks`.

##### D. Project Todos & All-Hands Records
- `add_project_todo`, `edit_project_todo`, `delete_project_todo`, `project_todos`.
- `add_project_all_hands_takeaway`, `edit_project_all_hands_takeaway`, `delete_project_all_hands_takeaway`, `project_all_hands_takeaways`.
- `add_project_all_hands_decision`, `edit_project_all_hands_decision`, `delete_project_all_hands_decision`, `project_all_hands_decisions`.
- `add_project_all_hands_action_item`, `edit_project_all_hands_action_item`, `delete_project_all_hands_action_item`, `project_all_hands_action_items`.

##### E. Knowledge, ADRs, Obsidian Notes & Tree Directory Items
- `add_project_knowledge_item`, `edit_project_knowledge_item`, `delete_project_knowledge_item`, `project_knowledge_items`, `knowledge_summary_items`.
- `add_project_decision_record`, `edit_project_decision_record`, `delete_project_decision_record`, `project_adrs`, `adrs`.
- `add_project_obsidian_note`, `edit_project_obsidian_note`, `delete_project_obsidian_note`, `project_obsidian_notes`.
- `add_tree_based_project_directory_item`, `edit_tree_based_project_directory_item`, `delete_tree_based_project_directory_item`, `project_directory_items`.
- `add_external_knowledge_asset`, `edit_external_knowledge_asset`, `delete_external_knowledge_asset`, `external_knowledge_assets`.
- `add_knowledge_activity_log`, `edit_knowledge_activity_log`, `delete_knowledge_activity_log`, `knowledge_activity_log`.

##### F. Rooms, Messaging & Topics
- `search_rooms`: Search rooms across projects by fuzzy query.
- `list_rooms` / `rooms`: List all chat rooms.
- `add_message`: Post a chat message to a room on behalf of a user or bot.
- `delete_message`: Remove a message.
- `add_action_message`, `add_decision_message`: Post structured cards into rooms.
- `add_loading_message`, `edit_loading_message`, `delete_loading_message`: Manage ephemeral typing/thinking states in rooms.
- `room_history_topics`, `message_topics`, `message_analysis`: Topic classification and analysis for room conversations.

##### G. Approvals & Governance
- `add_approval_request`: Create approval request with JSON payload, request type, room, and project context.
- `add_approve_request_with_message`: Post message and attach approval request atomically.
- `edit_approval_request`, `delete_approval_request`, `approval_requests`, `get_approval_request`.

##### H. Tasks & Estimation
- `tasks`: Full CRUD for project tasks with hierarchical parent/child relationships.
- `task_cost`: Calculate and update token, compute, and execution costs associated with tasks.

##### I. AI Configuration Introspection (Read-only)
- `list_ai_profiles`, `get_ai_profile`
- `list_ai_settings`, `get_ai_setting`
- `list_mcps`, `get_mcp`
- `list_tools`, `get_tool`
- `list_skills`, `get_skill`
- `list_ai_profile_tools`, `get_ai_profile_tool`
- `list_ai_profile_skills`, `get_ai_profile_skill`
- `list_ai_profile_mcps`, `get_ai_profile_mcp`

##### J. Core / Utility
- `hello`: Test greeting tool.

#### 2.3 Shared Fuzzy Resolution Helpers (`model_context_protocol/shared/helpers.py`)
Provides name-to-ID resolution when LLMs provide names instead of numeric identifiers:
- `username_fuzzy_match`: Matches string against project members (`name`, `display_name`, `username`, `email_address`).
- `project_name_fuzzy_match`: Matches against active projects (`name`, `slug`).
- `room_name_fuzzy`: Matches against rooms (`title`, `slug`).
- `bot_name_fuzzy_match`: Matches against configured bots (`name`, `profile_name`).
- Algorithm: Evaluates token overlap and string similarity ratio (`SequenceMatcher`), selecting candidates with score >= 0.4.

---

### 3. Agent / LLM Orchestration Layer (Hermes Integration)

#### 3.1 Hermes Client (`agent/hermes.py`)
- **API Surface**: Calls Hermes server (`BASE_URI`) using Bearer auth (`API_SERVER_KEY`).
- **Profile-Routed Paths**: Routes requests to `/p/{profile}/chat/completions` or root `/chat/completions`.
- **Session Tracking**: Propagates `X-Hermes-Session-Id` and `X-Hermes-Session-Key` headers across turns to preserve context.
- **Multipart Media Uploads**: Sends binary attachments alongside chat completion JSON in multipart requests.
- **Health & Gate Monitoring**: Queries `GET /api/status` to inspect `gateway_busy`, `active_agents`, and `active_sessions`.
- **Exception Logging**: Intercepts `httpx.HTTPError` and persists structured logs in `api_exceptions`.

#### 3.2 Prompt & Serialization Logic (`agent/hermes_logic.py`)
- **Formatting Hints**: Prepends system instructions requiring HTML tags (`<ul>`, `<li>`, `<a>`, `<b>`, `<pre>`) and prohibiting raw markdown for card rendering.
- **Collaboration Guidelines**: Injects instructions directing bots to maintain room-level Kanban boards.
- **Event-to-Prompt Translation (`build_space_event_message`)**: Formats space events as structured user prompts with event type tags.
- **Response Extraction**: Unpacks OpenAI-compatible completions format (`choices[0].message.content`).

---

### 4. Data Persistence & Observability Layer

W-bridge manages an internal SQLite database (`w_bridge.db`) with Alembic migrations:
1. `bots`: Tracks known bot agents, profile bindings (`profile_name`), and active flags.
2. `space_events`: Ingestion audit log containing Rails `space_event_id`, `event_type`, `event_data`, `dedupe_key`, `sent_date`, and `result`.
3. `space_event_dispatch_groups`: Primary dedupe record with unique constraint on `dedupe_key`, tracking `lead_space_event_id`, `status` (`pending`, `dispatched`, `duplicate_merged`, `error`), and `result`.
4. `mcp_call_logs`: Telemetry recording every MCP tool execution: `jsonrpc_id`, `tool_call_name`, `params_sanitized`, `is_error`, `error_message`, `result_preview`, `result_size`, and `duration_ms`.
5. `mcp_exceptions`: Full backtraces and context when an MCP tool fails.
6. `api_exceptions`: Log of failed outbound HTTP calls (service name, endpoint, status code, error type, message, request context).

---

### 5. Background Cron & Service Lifecycle

- **Background Ticker (`bus/cron.py`)**: Runs every 3 seconds. Checks queue depth, logs Hermes agent load (`/api/status`), and triggers worker execution.
- **Restart Hook (`/restart`)**: Touches a trigger file (`/triggers/restart`) on disk to instruct Docker/process supervisor to restart the container.

---

## Part 2: Bonfire Native Porting Plan

To replace W-bridge completely, Bonfire will implement these features natively in Ruby on Rails.

---

### Phase 1: Database Schema & Telemetry Migrations

Create Rails migrations in `db/migrate/` to absorb W-bridge's state tables directly into Bonfire's database.

#### Migration 1: `create_output_event_dispatch_groups`
```ruby
create_table :output_event_dispatch_groups do |t|
  t.string :dedupe_key, null: false
  t.bigint :lead_output_event_id
  t.string :status, null: false, default: "pending"
  t.datetime :dispatched_at
  t.text :result
  t.timestamps
end
add_index :output_event_dispatch_groups, :dedupe_key, unique: true
add_index :output_event_dispatch_groups, :status
```

#### Migration 2: `create_mcp_call_logs`
```ruby
create_table :mcp_call_logs do |t|
  t.string :jsonrpc_id
  t.string :tool_call_name, null: false
  t.json :params_sanitized
  t.boolean :is_error, null: false, default: false
  t.text :error_message
  t.text :result_preview
  t.integer :result_size
  t.integer :duration_ms
  t.timestamps
end
add_index :mcp_call_logs, :tool_call_name
add_index :mcp_call_logs, :created_at
```

#### Migration 3: `create_mcp_exceptions`
```ruby
create_table :mcp_exceptions do |t|
  t.string :tool_call_name, null: false
  t.string :exception_class, null: false
  t.text :error_message, null: false
  t.text :backtrace
  t.json :params_sanitized
  t.timestamps
end
```

#### Models to Create:
- `app/models/output_event_dispatch_group.rb`
- `app/models/mcp_call_log.rb`
- `app/models/mcp_exception.rb`

---

### Phase 2: Native JSON-RPC 2.0 MCP Controller & Framework

Build a native MCP server inside Rails adhering strictly to the JSON-RPC 2.0 specification.

#### 1. Routing (`config/routes.rb`)
```ruby
# MCP JSON-RPC endpoints
post "mcp", to: "mcp#handle"
post "action-mcp", to: "mcp#action"
post "read-mcp", to: "mcp#read"
post "knowledge-mcp", to: "mcp#knowledge"
post "task-mcp", to: "mcp#task"
```

#### 2. Controller (`app/controllers/mcp_controller.rb`)
- Inherits from `ApplicationController` (skipping CSRF check for API clients: `skip_before_action :verify_authenticity_token`).
- Implements JSON-RPC request parser, batching support (if needed), and error handling.
- Dispatches methods: `initialize`, `notifications/initialized`, `ping`, `tools/list`, and `tools/call`.
- Scopes tool registries based on route (`/action-mcp` exposes action tools, `/read-mcp` exposes read tools, `/mcp` exposes all).

#### 3. Core MCP Services
- `app/services/mcp/registry.rb`: Tool registry maintaining metadata and handler mappings for each tool name and category.
- `app/services/mcp/base_tool.rb`: Abstract class defining:
  - `name`: Identifier string.
  - `description`: Text shown to LLM in `tools/list`.
  - `input_schema`: JSON Schema definition for arguments.
  - `call(args)`: Execution method returning `{ content: [{ type: "text", text: result }], isError: boolean }`.
- `app/services/mcp/call_logger.rb`: Wraps tool calls in benchmark blocks, filters sensitive parameters, and records records to `McpCallLog` and `McpException`.
- `app/services/mcp/fuzzy_matcher.rb`: Ruby implementation of fuzzy matching for `User`, `Room`, `Project`, and `Bot` using token matching and string distance.

---

### Phase 3: Direct ActiveRecord MCP Tools Implementation

Port all 171 tools from Python to native Ruby classes under `app/services/mcp/tools/`. Because tools run directly inside Bonfire, they bypass HTTP and interact directly with ActiveRecord.

#### Tool Categories:
1. **Read Tools (`app/services/mcp/tools/read/`)**:
   - `AttentionItemsTool`, `AiConfirmTool`, `BlockersTool`, etc. -> Query `AttentionItem` directly.
   - `CompanyStatusPeriodTool`, `PrioritiesTool`, `ProgressTool`, etc. -> Query `CompanyStatusPeriod` and `CompanyStatusItem`.
   - `ProjectMilestonesTool`, `ProjectBottlenecksTool`, `ProjectTodosTool`, `ProjectAdrsTool`, `ProjectObsidianNotesTool`, `ProjectAllHandsTool`.
   - `AiProfilesTool`, `AiSettingsTool`, `McpsTool`, `ToolsTool`, `SkillsTool`.
   - `SearchRoomsTool`, `ListRoomsTool`.
2. **Action Tools (`app/services/mcp/tools/action/`)**:
   - `AddMessageTool`, `DeleteMessageTool`: Call `room.messages.create!` and broadcast via ActionCable.
   - `AddApprovalRequestTool`, `AddApproveRequestWithMessageTool`: Create `ApprovalRequest` with payload, resolving through `approval_requests`.
   - `AddProjectTodoTool`, `EditProjectTodoTool`, `DeleteProjectTodoTool`: Mutate `ProjectTodo` in database transactions.
   - `AddProjectBottleneckTool`, `AddProjectMilestoneTool`, `AddProjectDecisionRecordTool`.
   - `AddCompanyStatusPeriodTool`, `EditCompanyStatusPeriodTool`.
   - `AddLoadingMessageTool`, `EditLoadingMessageTool`, `DeleteLoadingMessageTool`.
3. **Knowledge & Task Tools (`app/services/mcp/tools/knowledge/`, `.../task/`)**:
   - `HelloTool`: Baseline test tool.
   - `TasksTool`, `TaskCostTool`: Manage hierarchical tasks and calculate cost metrics.

#### Example Tool Pattern:
```ruby
module Mcp
  module Tools
    module Action
      class AddProjectTodo < Mcp::BaseTool
        def name = "add_project_todo"
        def description = "Create a project todo item"
        
        def input_schema
          {
            type: :object,
            properties: {
              project_id: { type: :integer, description: "Project ID" },
              title: { type: :string, description: "Todo title" },
              completed: { type: :boolean, default: false }
            },
            required: %i[project_id title]
          }
        end

        def execute(args)
          project = Project.find(args[:project_id])
          todo = project.todos.create!(title: args[:title], completed: args[:completed] || false)
          success(todo.as_json)
        rescue ActiveRecord::RecordInvalid => e
          failure(e.message)
        end
      end
    end
  end
end
```

---

### Phase 4: Native Event Deduplication & ActiveJob Pipeline

Replace the external HTTP webhook delivery pipeline with an in-process ActiveJob deduplication and merge pipeline.

#### 1. Ingestion Decoupling (`app/services/output_events/recorder.rb`)
- Modify `OutputEvents::Recorder` so that when a business mutation occurs:
  - The `OutputEvent` is written to the database as before.
  - Instead of queueing `OutputEvents::DeliverJob` (which posts over HTTP), enqueue `OutputEvents::ProcessAndDispatchJob.perform_later(output_event.id)`.

#### 2. Deduplication Service (`app/services/output_events/deduplicator.rb`)
- Computes dedupe keys:
  - For `message_created`, `message_attachment_uploaded`, and `ai_question_asked`:
    `message:#{event.group_id}:#{event.event_data.dig('content_payload', 'room_id')}:#{event.event_id}`
  - For other events:
    `event:#{event.event_type}:#{event.event_id}:#{Digest::SHA256.hexdigest(event.event_data.to_json)[0..15]}`
- Performs atomic claim on `OutputEventDispatchGroup`.
- If key is already claimed, marks the incoming event as a duplicate member of that group.

#### 3. Settle Window & Dispatch Job (`app/jobs/output_events/process_and_dispatch_job.rb`)
- When a new group is claimed:
  - For message-family events, reschedule job execution with a 1.5-second settle delay:
    `ProcessAndDispatchJob.set(wait: 1.5.seconds).perform_later(group.id)`
  - When the settle window passes, invoke `OutputEvents::PayloadMerger` to combine all sibling events belonging to the group (attaching `bot_user_ids` and message text).
  - Triggers the Hermes client to dispatch the prompt to the AI agent.

---

### Phase 5: Native Ruby Hermes Client & Prompt Builder

Port the Hermes interaction layer from Python `httpx` to native Ruby.

#### 1. Hermes Client (`app/services/hermes/client.rb`)
- Implemented with `Faraday` or `Net::HTTP`.
- Handles Bearer auth (`HERMES_API_KEY`), timeout configuration, and profile routing (`/p/#{profile}/chat/completions`).
- Supports session headers (`X-Hermes-Session-Id`, `X-Hermes-Session-Key`).
- **Direct ActiveStorage streaming**: Directly reads attached files from ActiveStorage disk/cloud storage into the multipart form data, eliminating HTTP downloads.

#### 2. Prompt Builder (`app/services/hermes/prompt_builder.rb`)
- Formats merged `OutputEvent` payloads into user prompts.
- Injects standard system prompts: HTML tags required (`<ul>`, `<li>`, `<b>`, `<pre>`), no markdown, Kanban board collaboration patterns.

---

### Phase 6: Periodic Tasks & Recovery Worker

- Implement a recurring job: `app/jobs/output_events/reconcile_dispatches_job.rb`.
- Executed every minute (via SolidQueue recurring jobs or crontab).
- Re-enqueues unhandled or crashed dispatch groups older than 2 minutes.
- Queries Hermes `/api/status` to monitor agent health and record system status.

---

### Phase 7: Environment Variables & Configuration Porting (`.env`)

Port all runtime environment variables used by W-bridge into Bonfire's `.env`, `.env.example`, and configuration initializers (`config/initializers/hermes.rb`). Identify obsolete variables to retire.

#### 1. Variables to Migrate to Bonfire `.env` / `.env.example`:

| Environment Variable | Source Default / Example | Purpose in Bonfire |
|---|---|---|
| `HERMES_BASE_URI` (or `HERMES_BASE_URL`) | `http://127.0.0.1:8642` | Base URI of Hermes agent server for chat completions & profile routing (`/p/{profile}/...`). |
| `HERMES_API_KEY` | (W-bridge `API_KEY` / `API_SERVER_KEY`) | Bearer token authentication for Hermes API calls. |
| `HERMES_STATUS_URI` | `http://127.0.0.1:9119` | Endpoint for polling Hermes gateway health, active agent counts, and session load. |
| `HERMES_MODEL` | `hermes` / `deepseek-v4-flash` | Default LLM model identifier passed in completion requests. |
| `HERMES_DEFAULT_PROFILE` | `delegator` | Fallback agent profile name when not specified by the event or bot. |
| `HERMES_HTTP_TIMEOUT` | `60` (seconds) | HTTP timeout for Hermes completion calls. |
| `HERMES_MAX_ACTIVE_AGENTS` | `2` | Gate limit for active concurrent Hermes agent sessions. |
| `EVENT_MERGE_SETTLE_SECONDS` | `1.5` - `3.0` (seconds) | Settle window for consolidating sibling message webhooks before LLM dispatch. |
| `EVENT_RECOVERY_MAX_AGE_SECONDS` | `900` (15 minutes) | Lookback window for recovering pending or crashed dispatch groups across restarts. |
| `HERMES_EVENT_MAX_ATTACHMENTS` | `5` | Maximum number of attached files sent to Hermes per dispatch. |
| `HERMES_EVENT_MAX_ATTACHMENT_BYTES` | `20971520` (20MB) | File size cap for Hermes multipart attachment streaming. |

#### 2. Variables Made Obsolete & Retired:
- `OUTPUT_EVENTS_URL`: Retired. Bonfire no longer posts HTTP webhooks to an external service; events are processed in-process via ActiveJob.
- `OUTPUT_EVENTS_TOKEN`: Retired or relegated to external integrations only.
- `OUTPUT_BASE_URL` & `ROOM_BASE_URL`: Retired. MCP tools in Bonfire query ActiveRecord directly rather than calling external REST endpoints.
- `MASTER_KEY_TOKEN`: Retired. No external webhook ingestion gateway exists.
- `W_BRIDGE_PORT` / `PORT`: Retired. Bonfire runs under its existing Puma port (`3000`).
- `RELOAD`: Retired. Rails autoloading/reloading handles code changes in development.
- `SQLITE_DB_PATH` / `DATABASE_URL` (for W-bridge): Retired. All tables are merged into Bonfire's primary database (`config/database.yml`).

---

### Phase 8: Verification, Test Suite & W-bridge Retirement

#### 1. Test Suite Coverage
- **Unit Tests**:
  - Test every ported MCP tool against ActiveRecord models (verifying validation errors, permissions, and created records).
  - Test `OutputEvents::Deduplicator` verifying that concurrent sibling events (`message_created` + `ai_question_asked`) produce exactly one dispatch group.
  - Test `OutputEvents::PayloadMerger` ensuring `bot_user_ids` are preserved in the merged payload.
- **Controller Tests**:
  - Test `McpController` endpoints (`/mcp`, `/action-mcp`, `/read-mcp`) against JSON-RPC 2.0 specifications (`initialize`, `tools/list`, `tools/call`, malformed JSON error handling).
- **Hermes Client Mocks**:
  - Test multipart attachment upload and session header propagation using WebMock.

#### 2. Configuration & Deprecation
- Update `config/ai/ai_config.xml` and database seeds to point default MCP servers to `http://localhost:3000/action-mcp` and `http://localhost:3000/read-mcp`.
- Update `.env.example` in Bonfire with the new Hermes and event dispatch variables.
- Deprecate `OUTPUT_EVENTS_URL` pointing to W-bridge.
- Decommission and archive `W-bridge/`.

---

## Part 3: Python to Rails Mapping Reference

| W-bridge (Python / FastAPI) | Bonfire (Target Ruby on Rails) | Responsibility |
|---|---|---|
| `main.py` (`POST /space_events`) | `OutputEvents::Recorder` + `ProcessAndDispatchJob` | Event intake & queuing |
| `main.py` (`/action-mcp`, `/read-mcp`, etc.) | `app/controllers/mcp_controller.rb` | JSON-RPC 2.0 MCP server |
| `bus/dedupe.py` | `app/services/output_events/deduplicator.rb` | Message & event key deduplication |
| `bus/executors.py` | `app/jobs/output_events/process_and_dispatch_job.rb` | Settle window, payload merge, dispatch |
| `bus/cron.py` | `app/jobs/output_events/reconcile_dispatches_job.rb` | Dispatch recovery & health monitoring |
| `agent/hermes.py` | `app/services/hermes/client.rb` | HTTP client for Hermes completions |
| `agent/hermes_logic.py` | `app/services/hermes/prompt_builder.rb` | Prompt templates & HTML formatting rules |
| `model_context_protocol/*/server.py` | `app/services/mcp/registry.rb` | MCP tool catalog & dispatcher |
| `model_context_protocol/*/tools.py` | `app/services/mcp/tools/...` | Direct ActiveRecord tool logic |
| `model_context_protocol/shared/helpers.py` | `app/services/mcp/fuzzy_matcher.rb` | Name & identifier fuzzy matcher |
| `db/models.py: SpaceEventDispatchGroup` | `OutputEventDispatchGroup` model & migration | Atomic deduplication claim store |
| `db/models.py: McpCallLog` | `McpCallLog` model & migration | MCP execution telemetry & duration |
| `db/models.py: McpException` | `McpException` model & migration | MCP error backtrace logging |
| `space/api/*` (HTTP REST wrappers) | Direct ActiveRecord model queries (`Project.find`, etc.) | Domain execution (replaces HTTP calls) |
| `main.py: /restart` | Built-in Puma / Rails restart mechanism | Process control |
