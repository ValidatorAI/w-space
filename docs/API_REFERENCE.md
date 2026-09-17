# Bonfire HTTP API

Read-only-ish JSON API for automating Bonfire from external services (bots, integrations,
CI, etc.). All endpoints live under `/api` and share one authorization strategy.

## Authentication

Every request must include a bearer token that matches the `OUTPUT_EVENTS_TOKEN`
environment variable configured on the server:

```
Authorization: Bearer <OUTPUT_EVENTS_TOKEN>
```

- Missing/incorrect token → `401 Unauthorized`
- `OUTPUT_EVENTS_TOKEN` not set on the server → `500` (fails closed)

Implemented in [`Api::BaseController`](../app/controllers/api/base_controller.rb).

## Endpoint List

"Realtime" means the request also broadcasts a Turbo Stream / ActionCable
update to connected web clients in that room, in addition to the JSON response.

| Method | Path | Description | Realtime |
|---|---|---|---|
| GET | `/api/projects` | List all projects | No |
| GET | `/api/projects/:id` | Get a single project (by id or slug) | No |
| GET | `/api/rooms` | List all rooms | No |
| GET | `/api/rooms/:id` | Get a single room by room id | No |
| GET | `/api/rooms/:id/threads` | Get a room's threads (child rooms) | No |
| GET | `/api/rooms/search?q=` | Fuzzy search rooms by name | No |
| GET | `/api/rooms/:room_id/messages` | List messages for a room (paginated or not, includes `count`) | No |
| POST | `/api/rooms/:room_id/messages` | Post a message and/or file, on behalf of a user | **Yes** — Turbo Stream append + unread broadcast |
| GET | `/api/rooms/:room_id/messages/:id` | Get a single message | No |
| PATCH/PUT | `/api/rooms/:room_id/messages/:id` | Update a message's body and/or attachment | **Yes** — Turbo Stream replace |
| DELETE | `/api/rooms/:room_id/messages/:id` | Delete a message | **Yes** — Turbo Stream remove |
| GET | `/api/rooms/:room_id/messages/:id/attachment` | Download a message's uploaded file | No |
| GET | `/api/projects/:project_id/rooms` | Legacy project-scoped room listing (still supported) | No |
| GET | `/api/projects/:project_id/rooms/:id` | Legacy project-scoped room lookup | No |
| GET | `/api/projects/:project_id/rooms/:room_id/messages` | Legacy project-scoped message listing | No |
| POST | `/api/projects/:project_id/rooms/:room_id/messages` | Legacy project-scoped message create | **Yes** — Turbo Stream append + unread broadcast |
| GET | `/api/messages/:id` | Get a single message (flat, no room/project needed) | No |
| PATCH/PUT | `/api/messages/:id` | Update a message (flat) | **Yes** — Turbo Stream replace |
| DELETE | `/api/messages/:id` | Delete a message (flat) | **Yes** — Turbo Stream remove |
| GET | `/api/messages/:id/attachment` | Download a message's uploaded file (flat) | No |
| POST | `/api/rooms/:room_id/actions` | Send a real-time action (e.g. typing indicator) on behalf of a user | **Yes** — ActionCable broadcast (that's its only purpose) |
| POST | `/api/rooms/:room_id/decisions` | Approve/confirm/deny/cancel an approval request on behalf of a user | **Yes** — Turbo Stream replace of the approval request card |
| GET | `/api/rooms/:room_id/approval_requests` | List approval requests for a room (paginated or not, includes `count`) | No |
| POST | `/api/rooms/:room_id/approval_requests` | Create an approval request in a room | **Yes** — Turbo Stream replace of the parent message or approval card |
| GET | `/api/rooms/:room_id/approval_requests/:id` | Get a single approval request | No |
| PATCH/PUT | `/api/rooms/:room_id/approval_requests/:id` | Update an approval request | **Yes** — Turbo Stream replace |
| DELETE | `/api/rooms/:room_id/approval_requests/:id` | Delete an approval request | **Yes** — Turbo Stream replace (message) or remove (standalone) |
| GET | `/api/projects/:project_id/rooms/:room_id/approval_requests` | Legacy project-scoped approval request listing | No |
| POST | `/api/projects/:project_id/rooms/:room_id/approval_requests` | Legacy project-scoped approval request create | **Yes** |
| GET | `/api/projects/:project_id/rooms/:room_id/approval_requests/:id` | Legacy project-scoped approval request lookup | No |
| PATCH/PUT | `/api/projects/:project_id/rooms/:room_id/approval_requests/:id` | Legacy project-scoped approval request update | **Yes** |
| DELETE | `/api/projects/:project_id/rooms/:room_id/approval_requests/:id` | Legacy project-scoped approval request delete | **Yes** |
| GET | `/api/attention_items` | List attention items with optional filtering and pagination | No |
| GET | `/api/attention_items/:id` | Get a single attention item | No |
| POST | `/api/attention_items` | Create an attention item | No |
| PATCH/PUT | `/api/attention_items/:id` | Update an attention item | No |
| DELETE | `/api/attention_items/:id` | Delete an attention item | No |
| GET | `/api/company_status_periods` | List all company status periods | No |
| GET | `/api/company_status_periods/:id` | Get a company status period (by ID) | No |
| GET | `/api/company_status_periods/current` | Get the current active company status period | No |
| GET | `/api/company_status_periods/by_slug/:slug` | Get a company status period by slug | No |
| GET | `/api/company_status_periods/by_name?name=` | Get a company status period by exact name (case-insensitive) | No |
| POST | `/api/company_status_periods` | Create a company status period | No |
| PATCH/PUT | `/api/company_status_periods/:id` | Update a company status period | No |
| DELETE | `/api/company_status_periods/:id` | Delete a company status period | No |
| GET | `/api/company_status_items` | List company status items (supports filtering and pagination) | No |
| GET | `/api/company_status_items/:id` | Get a single company status item | No |
| GET | `/api/company_status_items/by_period?company_status_period_id=` | List items for a specific company status period | No |
| GET | `/api/company_status_items/advanced_filter` | Advanced filter items by multiple criteria | No |
| POST | `/api/company_status_items` | Create a company status item | No |
| PATCH/PUT | `/api/company_status_items/:id` | Update a company status item | No |
| DELETE | `/api/company_status_items/:id` | Delete a company status item | No |
| GET | `/api/projects/:project_id/users` | List project members (paginated) | No |
| GET | `/api/projects/:project_id/users/:id` | Get a single project member | No |
| GET | `/api/projects/:project_id/project_all_hands_takeaways` | List project all-hands takeaways (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/project_all_hands_takeaways/:id` | Get a single project all-hands takeaway | No |
| POST | `/api/projects/:project_id/project_all_hands_takeaways` | Create a project all-hands takeaway | No |
| PATCH/PUT | `/api/projects/:project_id/project_all_hands_takeaways/:id` | Update a project all-hands takeaway | No |
| DELETE | `/api/projects/:project_id/project_all_hands_takeaways/:id` | Delete a project all-hands takeaway | No |
| GET | `/api/projects/:project_id/project_all_hands_decisions` | List project all-hands decisions (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/project_all_hands_decisions/:id` | Get a single project all-hands decision | No |
| POST | `/api/projects/:project_id/project_all_hands_decisions` | Create a project all-hands decision | No |
| PATCH/PUT | `/api/projects/:project_id/project_all_hands_decisions/:id` | Update a project all-hands decision | No |
| DELETE | `/api/projects/:project_id/project_all_hands_decisions/:id` | Delete a project all-hands decision | No |
| GET | `/api/projects/:project_id/project_all_hands_action_items` | List project all-hands action items (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/project_all_hands_action_items/:id` | Get a single project all-hands action item | No |
| POST | `/api/projects/:project_id/project_all_hands_action_items` | Create a project all-hands action item | No |
| PATCH/PUT | `/api/projects/:project_id/project_all_hands_action_items/:id` | Update a project all-hands action item | No |
| DELETE | `/api/projects/:project_id/project_all_hands_action_items/:id` | Delete a project all-hands action item | No |
| GET | `/api/projects/:project_id/knowledge_items` | List knowledge items for project (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/knowledge_items/:id` | Get a single knowledge item | No |
| POST | `/api/projects/:project_id/knowledge_items` | Create a knowledge item | No |
| PATCH/PUT | `/api/projects/:project_id/knowledge_items/:id` | Update a knowledge item | No |
| DELETE | `/api/projects/:project_id/knowledge_items/:id` | Delete a knowledge item | No |
| GET | `/api/projects/:project_id/external_assets` | List external assets for project (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/external_assets/:id` | Get a single external asset | No |
| POST | `/api/projects/:project_id/external_assets` | Create an external asset | No |
| PATCH/PUT | `/api/projects/:project_id/external_assets/:id` | Update an external asset | No |
| DELETE | `/api/projects/:project_id/external_assets/:id` | Delete an external asset | No |
| GET | `/api/projects/:project_id/adrs` | List ADRs for project (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/adrs/:id` | Get a single ADR | No |
| POST | `/api/projects/:project_id/adrs` | Create an ADR | No |
| PATCH/PUT | `/api/projects/:project_id/adrs/:id` | Update an ADR | No |
| DELETE | `/api/projects/:project_id/adrs/:id` | Delete an ADR | No |
| GET | `/api/projects/:project_id/knowledge_activities` | List knowledge activities for project (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/knowledge_activities/:id` | Get a single knowledge activity | No |
| POST | `/api/projects/:project_id/knowledge_activities` | Create a knowledge activity | No |
| PATCH/PUT | `/api/projects/:project_id/knowledge_activities/:id` | Update a knowledge activity | No |
| DELETE | `/api/projects/:project_id/knowledge_activities/:id` | Delete a knowledge activity | No |
| GET | `/api/projects/:project_id/directory_items` | List directory items for project (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/directory_items/:id` | Get a single directory item | No |
| POST | `/api/projects/:project_id/directory_items` | Create a directory item (supports multipart file upload) | No |
| PATCH/PUT | `/api/projects/:project_id/directory_items/:id` | Update a directory item (supports multipart file upload) | No |
| DELETE | `/api/projects/:project_id/directory_items/:id` | Delete a directory item (cleans up file on disk) | No |
| GET | `/api/projects/:project_id/obsidian_notes` | List obsidian notes for project (optional `active` filter & paginated) | No |
| GET | `/api/projects/:project_id/obsidian_notes/:id` | Get a single obsidian note | No |
| POST | `/api/projects/:project_id/obsidian_notes` | Create an obsidian note (supports multipart file upload) | No |
| PATCH/PUT | `/api/projects/:project_id/obsidian_notes/:id` | Update an obsidian note (supports multipart file upload) | No |
| DELETE | `/api/projects/:project_id/obsidian_notes/:id` | Delete an obsidian note (cleans up internal file on disk) | No |
| GET | `/api/projects/:project_id/project_bottlenecks` | List project bottlenecks (filterable by `created_at` range, `active`, `severity`, & paginated) | No |
| GET | `/api/projects/:project_id/project_bottlenecks/:id` | Get a single project bottleneck | No |
| POST | `/api/projects/:project_id/project_bottlenecks` | Create a project bottleneck | No |
| PATCH/PUT | `/api/projects/:project_id/project_bottlenecks/:id` | Update a project bottleneck | No |
| DELETE | `/api/projects/:project_id/project_bottlenecks/:id` | Delete a project bottleneck | No |
| GET | `/api/projects/:project_id/project_todos` | List project todos (filterable by `created_at` range, `completed`/`active`, & paginated) | No |
| GET | `/api/projects/:project_id/project_todos/:id` | Get a single project todo | No |
| POST | `/api/projects/:project_id/project_todos` | Create a project todo | No |
| PATCH/PUT | `/api/projects/:project_id/project_todos/:id` | Update a project todo | No |
| DELETE | `/api/projects/:project_id/project_todos/:id` | Delete a project todo | No |
| GET | `/api/projects/:project_id/project_milestones` | List project milestones (filterable by `created_at` range, `active`, & paginated) | No |
| GET | `/api/projects/:project_id/project_milestones/:id` | Get a single project milestone | No |
| POST | `/api/projects/:project_id/project_milestones` | Create a project milestone | No |
| PATCH/PUT | `/api/projects/:project_id/project_milestones/:id` | Update a project milestone | No |
| DELETE | `/api/projects/:project_id/project_milestones/:id` | Delete a project milestone | No |

Note: message ids are globally unique (not scoped per room), so the flat
`/api/messages/:id` routes work regardless of which room the message belongs to.

---

## Projects

### `GET /api/projects`

Returns all projects.

**Response** `200`
```json
[
  { "id": 1, "name": "Acme", "slug": "acme", "path": "...", "description": null, "private": false,
    "short_code": null, "current_phase": "Phase 1: Project Setup", "progress_percent": 0,
    "roadmap": null, "recently_completed": null, "budget_total": "0.0", "budget_spent": "0.0",
    "created_at": "...", "updated_at": "..." }
]
```

### `GET /api/projects/:id`

`:id` may be the numeric primary key or the project `slug`.

**Response** `200` — single project object (same shape as above).
**Errors** `404` — project not found.

---

## Rooms

Room records are first-class entities in the API. The primary contract is room-based: the room id is sufficient to resolve the room, and `project_id` is optional for backward compatibility.

### `GET /api/rooms`

Lists all rooms.

**Response** `200`
```json
[
  { "id": 1, "name": "General", "type": "Rooms::Project", "description": null, "private": false,
    "parent_id": null, "project_id": 1, "creator_id": 1, "archived_at": null,
    "created_at": "...", "updated_at": "..." }
]
```

### `GET /api/rooms/:id`

Single room lookup by room id.

**Errors** `404` — room not found.

### `GET /api/rooms/:id/threads`

Returns the room's threads — child rooms whose `parent_id` points to `:id`.

**Response** `200` — array of room objects (same shape as index).

### `GET /api/rooms/search?q=<term>`

Fuzzy, case-insensitive substring search on room name, ranked by relevance
(exact match > starts-with > contains).

**Errors**
- `400` — missing `q` param

### Legacy project-scoped room routes

The following project-scoped room endpoints remain supported for compatibility, but they are not required for room-based requests:

- `GET /api/projects/:project_id/rooms`
- `GET /api/projects/:project_id/rooms/:id`
- `GET /api/projects/:project_id/rooms/:id/threads`
- `GET /api/projects/:project_id/rooms/search?q=<term>`

---

## Messages

### `GET /api/rooms/:room_id/messages`

Supports both modes:

- No `page` param → `{ "count": N, "messages": [...] }` (full list, chronological order).
- With `page` param → `{ "count": N, "page": P, "per_page": PP, "messages": [...] }`
  (offset/limit paginated; `per_page` default 40, max 200).

Each message serializes as:
```json
{
  "id": 1, "room_id": 1, "creator_id": 1, "creator_type": "User",
  "system": false, "system_type": null, "created_at": "...", "updated_at": "...",
  "body": "plain text body",
  "has_attachment": false, "attachment_filename": null,
  "attachment_content_type": null, "attachment_url": null
}
```

### `POST /api/rooms/:room_id/messages`

Creates a message on behalf of a user. Accepts `body` and/or a multipart
`attachment` file — at least one is required.

**Params**: `user_id` (required), `body` (optional), `attachment` (optional file)

**Realtime:** Yes — broadcasts a Turbo Stream append to the room and an `unread_rooms` ActionCable event.

**Response** `201` — the created message (same shape as above).
**Errors**
- `404` — room or user not found
- `400` — neither `body` nor `attachment` provided
- `422` — validation error

### `GET /api/rooms/:room_id/messages/:id`

Single message lookup, scoped to the room.

### `PATCH`/`PUT /api/rooms/:room_id/messages/:id`

Updates a message's `body` and/or `attachment` (at least one required).

**Realtime:** Yes — broadcasts a Turbo Stream replace, mirroring the web app's edit flow.

### `DELETE /api/rooms/:room_id/messages/:id`

Deletes the message and broadcasts removal. Returns `204 No Content`.

**Realtime:** Yes — broadcasts a Turbo Stream remove.

### `GET /api/rooms/:room_id/messages/:id/attachment`

Streams the message's uploaded file.

**Query param**: `disposition=attachment` forces a download instead of inline display.

**Errors** `404` — room/message not found, or message has no attachment.

### Legacy project-scoped message routes

The following project-scoped message routes are still supported for compatibility:

- `GET /api/projects/:project_id/rooms/:room_id/messages`
- `POST /api/projects/:project_id/rooms/:room_id/messages`
- `GET /api/projects/:project_id/rooms/:room_id/messages/:id`
- `PATCH`/`PUT /api/projects/:project_id/rooms/:room_id/messages/:id`
- `DELETE /api/projects/:project_id/rooms/:room_id/messages/:id`
- `GET /api/projects/:project_id/rooms/:room_id/messages/:id/attachment`

### Flat message routes

Since message `id`s are globally unique, the following equivalent routes work
without needing `project_id`/`room_id` in the path:

- `GET /api/messages/:id`
- `PATCH`/`PUT /api/messages/:id`
- `DELETE /api/messages/:id`
- `GET /api/messages/:id/attachment`

Same params, behavior, and responses as their nested counterparts above.

---

## Actions

### `POST /api/rooms/:room_id/actions`

Broadcasts a real-time action to the room on behalf of a user (e.g. typing
indicators), the same mechanism the web client uses.

**Realtime:** Yes — this endpoint's only effect is an ActionCable broadcast; there is no persisted resource.

**Params**: `user_id` (required), `action_type` (required — one of `typing_start`, `typing_stop`)

> Note: the param is `action_type`, not `action` — `params[:action]` is reserved
> by Rails routing and always resolves to the controller action name.

**Response** `202 Accepted`
```json
{ "status": "ok", "action": "typing_start" }
```

**Errors**
- `404` — room or user not found
- `400` — unsupported `action_type`

---

## Decisions

### `POST /api/rooms/:room_id/decisions`

Resolves an approval request (a "decision") on behalf of a user.

**Params**:
- `user_id` (required)
- `approval_request_id` (required — must belong to the room)
- `decision` (required — one of `approve`, `confirm`, `deny`, `cancel`)
- `note` (optional)

**Realtime:** Yes — broadcasts a Turbo Stream replace of the approval request card in the room.

**Response** `200` — the updated approval request:
```json
{
  "id": 1, "room_id": 1, "message_id": null, "agent_id": null,
  "request_type": "decision", "status": "approved",
  "requested_at": "...", "resolved_at": "...", "resolved_by_id": 1
}
```

**Errors**
- `404` — room, user, or approval request not found (or approval
  request belongs to a different room)
- `400` — unsupported `decision`
- `422` — validation error

---

## Approval Requests

Room-scoped CRUD for `ApprovalRequest` records. Approval requests can be attached to a room directly or to a message inside the room (`message_id`).

> **Note:** `POST /api/rooms/:room_id/decisions` is still the preferred way to *resolve* an approval request on behalf of a user. It records an `ApprovalRequestAction`, resolves linked attention items, and may create a `ProjectAdr`. The endpoints below are for managing the raw approval request record.

### `GET /api/rooms/:room_id/approval_requests`

Lists approval requests for a room, most recently requested first.

**Params**:
- `page` (optional — default: 1)
- `per_page` (optional — default: 40, max: 200)

**Response** `200` (paginated when `page` is provided):
```json
{
  "count": 2,
  "page": 1,
  "per_page": 40,
  "approval_requests": [
    {
      "id": 1,
      "room_id": 1,
      "message_id": 5,
      "agent_id": null,
      "request_type": "decision",
      "status": "pending",
      "requested_at": "...",
      "resolved_at": null,
      "resolved_by_id": null,
      "created_at": "...",
      "updated_at": "...",
      "decision_text": "Ship it"
    }
  ]
}
```

### `GET /api/rooms/:room_id/approval_requests/:id`

Fetches a single approval request.

**Response** `200` — approval request object.

**Errors** `404` — room or approval request not found, or approval request does not belong to the room.

### `POST /api/rooms/:room_id/approval_requests`

Creates a new approval request in the room.

**Params**:
- `request_type` (required — e.g. `decision`, `knowledge_proposal`)
- `payload` (optional JSON object)
- `message_id` (optional — must belong to the room)
- `agent_id` (optional)
- `status` (optional — defaults to `pending`)
- `requested_at` (optional — defaults to current time)

**Realtime:** Yes — if `message_id` is provided, replaces the message presentation in the room; otherwise replaces the standalone approval request card.

**Response** `201` — the created approval request.

**Errors**
- `404` — room not found
- `422` — validation error, or `message_id` belongs to a different room

### `PATCH/PUT /api/rooms/:room_id/approval_requests/:id`

Updates an approval request.

**Params**: any of `request_type`, `payload`, `message_id`, `agent_id`, `status`, `requested_at`, `resolved_at`, `resolved_by_id`.

**Status transition note:** If `status` is changed to a resolved state (`approved`, `denied`, or `canceled`) and `resolved_at` is blank, it is automatically set to the current time. Direct status edits here do **not** create `ApprovalRequestAction` records or trigger attention-item/ADR side effects — use `POST /api/rooms/:room_id/decisions` for that.

**Realtime:** Yes — replaces the parent message presentation or approval card.

**Response** `200` — the updated approval request.

**Errors**
- `404` — room or approval request not found
- `422` — validation error

### `DELETE /api/rooms/:room_id/approval_requests/:id`

Deletes an approval request.

**Realtime:** Yes — if `message_id` is present, the message presentation is re-rendered without the card; otherwise the standalone card is removed from the room.

**Response** `204 No Content`.

**Errors** `404` — room or approval request not found.

---

## Attention Items

### `GET /api/attention_items`

Lists attention items. Supports pagination and rich optional filters:
- Filtering by field: `id`, `category`, `title`, `meta_text`, `due_at`, `overdue`, `status`, `project_id`, `room_id`, `user_id`, `source_id`, `source_type`, `target_id`, `target_type`, `action_label`, `ai_confirm`
- Date range filtering: `created_at_gt`, `created_at_lt`
- Pagination: `page` (default: 1), `per_page` (default: 40, max: 200)

**Response** `200` (Paginated)
```json
{
  "count": 12,
  "page": 1,
  "per_page": 40,
  "attention_items": [
    {
      "id": 1,
      "category": "decision_waiting",
      "title": "Need signoff on database migration",
      "meta_text": "Phase 2 rollout",
      "due_at": "2026-09-10T12:00:00.000Z",
      "overdue": false,
      "status": "pending",
      "project_id": 1,
      "room_id": 2,
      "user_id": 3,
      "source_id": null,
      "source_type": null,
      "target_id": null,
      "target_type": null,
      "action_label": "Review Migration",
      "ai_confirm": false,
      "created_at": "...",
      "updated_at": "...",
      "resolved_at": null,
      "resolved_by_id": null
    }
  ]
}
```

### `GET /api/attention_items/:id`

Fetches a single attention item by ID.

**Response** `200` — attention item object.
**Errors** `404` — attention item not found.

### `POST /api/attention_items`

Creates a new attention item.

**Params**:
- `title` (required)
- `category` (required)
- Optional: `meta_text`, `due_at`, `status`, `overdue`, `project_id`, `room_id`, `user_id`, `source_id`, `source_type`, `target_id`, `target_type`, `action_label`, `ai_confirm`

**Response** `201 Created` — created attention item object.
**Errors** `400` (missing required fields), `404` (associated user/project/room not found), `422` (validation error).

### `PATCH`/`PUT /api/attention_items/:id`

Updates an existing attention item.

**Response** `200` — updated attention item object.
**Errors** `404` — attention item not found, `422` — validation error.

### `DELETE /api/attention_items/:id`

Deletes an attention item.

**Response** `204 No Content`.
**Errors** `404` — attention item not found.

---

## Company Status Periods

### `GET /api/company_status_periods`

Returns all company status periods ordered by position and dates.

**Response** `200`
```json
{
  "count": 2,
  "company_status_periods": [
    {
      "id": 1,
      "account_id": 1,
      "name": "Q3 2026",
      "slug": "q3-2026",
      "current": true,
      "starts_on": "2026-07-01",
      "ends_on": "2026-09-30",
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/company_status_periods/:id`

Fetches a company status period by ID.

### `GET /api/company_status_periods/current`

Fetches the current active company status period.

### `GET /api/company_status_periods/by_slug/:slug`

Fetches a company status period by its slug.

### `GET /api/company_status_periods/by_name?name=<name>`

Fetches a company status period by case-insensitive name.

### `POST /api/company_status_periods`

Creates a new company status period.

**Params**: `name` (required), `slug` (optional/auto-generated), `current`, `starts_on`, `ends_on`, `position`.

**Response** `201 Created`.

### `PATCH`/`PUT /api/company_status_periods/:id`

Updates a company status period.

### `DELETE /api/company_status_periods/:id`

Deletes a company status period. Returns `204 No Content`.

---

## Company Status Items

### `GET /api/company_status_items`

Lists company status items with pagination and optional field filtering.

### `GET /api/company_status_items/:id`

Fetches a single company status item.

### `GET /api/company_status_items/by_period?company_status_period_id=<id>`

Lists company status items scoped to a specific period ID.

### `GET /api/company_status_items/advanced_filter`

Advanced filtering endpoint supporting optional filters:
- `company_status_period_id`, `project_id`, `category`, `status`, `health`, `badge`, `owner_name`, `source_type`
- `created_at_gt`, `created_at_lt`
- `page`, `per_page`

### `POST /api/company_status_items`

Creates a company status item.

**Params**: `company_status_period_id` (required), `title` (required), `category` (required), `status`, `health`, `badge`, `summary`, `details`, `owner_name`, `position`, `project_id`.

### `PATCH`/`PUT /api/company_status_items/:id`

Updates a company status item.

### `DELETE /api/company_status_items/:id`

Deletes a company status item. Returns `204 No Content`.

---

## Project Users

### `GET /api/projects/:project_id/users`

Lists users/members associated with a project.

**Response** `200`
```json
{
  "count": 3,
  "page": 1,
  "per_page": 40,
  "project_users": [
    {
      "id": 1,
      "name": "Alice Smith",
      "display_name": "Alice",
      "email_address": "alice@example.com",
      "job_title": "Lead Engineer",
      "status": "active",
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/users/:id`

Fetches a single user if they belong to the project.

---

## Project All-Hands Takeaways

### `GET /api/projects/:project_id/project_all_hands_takeaways`

Lists all-hands takeaways for a project. Supports optional `active=true|false` filtering and pagination (`page`, `per_page`).

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "project_all_hands_takeaways": [
    {
      "id": 1,
      "project_id": 1,
      "category": "Performance",
      "content": "Latency reduced by 40%.",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/project_all_hands_takeaways/:id`
Fetches a single takeaway.

### `POST /api/projects/:project_id/project_all_hands_takeaways`
Creates a takeaway. **Params**: `category` (required), `content` (required), `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/project_all_hands_takeaways/:id`
Updates a takeaway.

### `DELETE /api/projects/:project_id/project_all_hands_takeaways/:id`
Deletes a takeaway. Returns `204 No Content`.

---

## Project All-Hands Decisions

### `GET /api/projects/:project_id/project_all_hands_decisions`

Lists all-hands decisions for a project. Supports optional `active=true|false` filtering and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "project_all_hands_decisions": [
    {
      "id": 1,
      "project_id": 1,
      "title": "Migrate to SQLite 3 WAL mode",
      "basis": "High read concurrency requirement",
      "impact": "Zero lock contention",
      "badge": "Approved",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/project_all_hands_decisions/:id`
Fetches a single all-hands decision.

### `POST /api/projects/:project_id/project_all_hands_decisions`
Creates an all-hands decision. **Params**: `title` (required), `basis`, `impact`, `badge`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/project_all_hands_decisions/:id`
Updates an all-hands decision.

### `DELETE /api/projects/:project_id/project_all_hands_decisions/:id`
Deletes an all-hands decision. Returns `204 No Content`.

---

## Project All-Hands Action Items

### `GET /api/projects/:project_id/project_all_hands_action_items`

Lists all-hands action items for a project. Supports optional `active=true|false` filtering and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "project_all_hands_action_items": [
    {
      "id": 1,
      "project_id": 1,
      "title": "Complete DB benchmark suite",
      "assignee_name": "Alice",
      "due_date": "2026-09-15",
      "completed": false,
      "completed_at": null,
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/project_all_hands_action_items/:id`
Fetches a single action item.

### `POST /api/projects/:project_id/project_all_hands_action_items`
Creates an action item. **Params**: `title` (required), `assignee_name`, `due_date`, `completed`, `completed_at`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/project_all_hands_action_items/:id`
Updates an action item.

### `DELETE /api/projects/:project_id/project_all_hands_action_items/:id`
Deletes an action item. Returns `204 No Content`.

---

## Knowledge Items

### `GET /api/projects/:project_id/knowledge_items`

Lists knowledge items for a project. Supports `active=true|false` and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "knowledge_items": [
    {
      "id": 1,
      "project_id": 1,
      "title": "Architecture Guidelines",
      "description": "Service objects live in app/services.",
      "badge": "Architecture",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/knowledge_items/:id`
Fetches a single knowledge item.

### `POST /api/projects/:project_id/knowledge_items`
Creates a knowledge item. **Params**: `title` (required), `description` (required), `badge`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/knowledge_items/:id`
Updates a knowledge item.

### `DELETE /api/projects/:project_id/knowledge_items/:id`
Deletes a knowledge item. Returns `204 No Content`.

---

## External Assets

### `GET /api/projects/:project_id/external_assets`

Lists external documentation/asset links for a project. Supports `active=true|false` and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "external_assets": [
    {
      "id": 1,
      "project_id": 1,
      "title": "System Architecture Figma",
      "url": "https://www.figma.com/file/...",
      "doc_type": "Design",
      "icon": "figma",
      "source_type": "external_url",
      "meta_text": "Figma File",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/external_assets/:id`
Fetches a single external asset.

### `POST /api/projects/:project_id/external_assets`
Creates an external asset. **Params**: `title` (required), `url` (required), `doc_type`, `icon`, `source_type` (`internal_file` | `external_url`), `meta_text`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/external_assets/:id`
Updates an external asset.

### `DELETE /api/projects/:project_id/external_assets/:id`
Deletes an external asset. Returns `204 No Content`.

---

## Architectural Decision Records (ADRs)

### `GET /api/projects/:project_id/adrs`

Lists ADRs for a project. Supports `active=true|false` and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "adrs": [
    {
      "id": 1,
      "project_id": 1,
      "identifier": "ADR-001",
      "title": "Use SQLite with WAL mode",
      "decision_date": "2026-08-15",
      "status": "accepted",
      "file_path": "docs/adr/001-sqlite-wal.md",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/adrs/:id`
Fetches a single ADR.

### `POST /api/projects/:project_id/adrs`
Creates an ADR. **Params**: `identifier` (required), `title` (required), `decision_date`, `status` (`proposed` | `accepted` | `deprecated` | `superseded`), `file_path`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/adrs/:id`
Updates an ADR.

### `DELETE /api/projects/:project_id/adrs/:id`
Deletes an ADR. Returns `204 No Content`.

---

## Knowledge Activities

### `GET /api/projects/:project_id/knowledge_activities`

Lists knowledge audit/activity logs for a project. Supports `active=true|false` and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "knowledge_activities": [
    {
      "id": 1,
      "project_id": 1,
      "actor_name": "Alice",
      "actor_color": "#3b82f6",
      "action_text": "Updated [[Infrastructure Routing]]",
      "target_path": "docs/infra.md",
      "target_url": null,
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/knowledge_activities/:id`
Fetches a single knowledge activity.

### `POST /api/projects/:project_id/knowledge_activities`
Creates a knowledge activity. **Params**: `actor_name` (required), `action_text` (required), `actor_color`, `target_path`, `target_url`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/knowledge_activities/:id`
Updates a knowledge activity.

### `DELETE /api/projects/:project_id/knowledge_activities/:id`
Deletes a knowledge activity. Returns `204 No Content`.

---

## Directory Items

Manages the project's file hierarchy stored on disk at `storage/projects/:project_id/`.

### `GET /api/projects/:project_id/directory_items`

Lists directory items for a project. Supports `active=true|false` and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "directory_items": [
    {
      "id": 1,
      "project_id": 1,
      "parent_id": null,
      "name": "architecture.md",
      "item_type": "file",
      "file_path": "architecture.md",
      "content": "# Architecture Overview...",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/directory_items/:id`
Fetches a single directory item.

### `POST /api/projects/:project_id/directory_items`

Creates a directory item with automatic project storage directory initialization (`storage/projects/:project_id/`).

**Supports Multipart File Upload**:
- `file` (optional multipart upload): Automatically saves the file into `storage/projects/:project_id/[file_path]`.
- Params: `name`, `item_type` (`file` | `directory`), `file_path`, `parent_id`, `content`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/directory_items/:id`

Updates a directory item. Also accepts a multipart `file` parameter to overwrite file contents in storage.

### `DELETE /api/projects/:project_id/directory_items/:id`

Deletes a directory item from the database and removes the associated file from `storage/projects/:project_id/`. Returns `204 No Content`.

---

## Obsidian Notes

Manages Obsidian graph and note exports stored under `storage/projects/:project_id/`.

### `GET /api/projects/:project_id/obsidian_notes`

Lists obsidian notes for a project. Supports `active=true|false` and pagination.

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "obsidian_notes": [
    {
      "id": 1,
      "project_id": 1,
      "title": "System Architecture Note",
      "tags": "#architecture, #backend",
      "content": "Main entrypoint notes.",
      "html_source_type": "internal_file",
      "html_source_path": "notes/main.html",
      "active": true,
      "position": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### `GET /api/projects/:project_id/obsidian_notes/:id`
Fetches a single obsidian note.

### `POST /api/projects/:project_id/obsidian_notes`

Creates an obsidian note with automatic project storage directory initialization (`storage/projects/:project_id/`).

**Supports Multipart File Upload**:
- `file` (optional multipart upload): Automatically writes the uploaded HTML/note file into `storage/projects/:project_id/[html_source_path]`.
- Params: `title`, `tags`, `content`, `html_source_type` (`internal_file` | `external_url`), `html_source_path`, `active`, `position`.

### `PATCH`/`PUT /api/projects/:project_id/obsidian_notes/:id`

Updates an obsidian note. Also accepts a multipart `file` parameter to update/overwrite the HTML file in storage.

### `DELETE /api/projects/:project_id/obsidian_notes/:id`

Deletes an obsidian note from the database and cleans up the associated internal HTML file from `storage/projects/:project_id/`. Returns `204 No Content`.

---

## Project Bottlenecks

### `GET /api/projects/:project_id/project_bottlenecks`

Lists bottlenecks for a project. Supports date range filtering on `created_at`, active/resolved filtering, severity filtering, and pagination.

**Query Parameters:**
- Date range:
  - `created_at_gt` / `from` / `starts_at` / `start_date`: items created after date/time
  - `created_at_gte`: items created on or after date/time
  - `created_at_lt` / `to` / `ends_at` / `end_date`: items created before date/time
  - `created_at_lte`: items created on or before date/time
- Active/Resolved status:
  - `active=true` (unresolved bottlenecks, `resolved_at` is null)
  - `active=false` (resolved bottlenecks)
- Severity:
  - `severity=active` | `warning` | `critical` | `resolved`
- Pagination:
  - `page` (default: 1)
  - `per_page` (default: 40, max: 200)

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "project_bottlenecks": [
    {
      "id": 1,
      "project_id": 1,
      "title": "Obsidian Vault Indexing Timeout",
      "description": "Large attachments slow down sync",
      "severity": "active",
      "resolved_at": null,
      "position": 1,
      "created_at": "2026-09-01T10:00:00.000Z",
      "updated_at": "2026-09-01T10:00:00.000Z"
    }
  ]
}
```

### `GET /api/projects/:project_id/project_bottlenecks/:id`

Fetches a single project bottleneck.

### `POST /api/projects/:project_id/project_bottlenecks`

Creates a project bottleneck.

**Params**: `title` (required), `description`, `severity`, `position`, `resolved_at`.

**Response** `201 Created`.

### `PATCH`/`PUT /api/projects/:project_id/project_bottlenecks/:id`

Updates a project bottleneck. Also accepts `resolved=true|false` to easily toggle resolution timestamp.

**Response** `200 OK`.

### `DELETE /api/projects/:project_id/project_bottlenecks/:id`

Deletes a project bottleneck. Returns `204 No Content`.

---

## Project Todos

### `GET /api/projects/:project_id/project_todos`

Lists todos for a project. Supports date range filtering on `created_at`, completion status filtering, and pagination.

**Query Parameters:**
- Date range:
  - `created_at_gt` / `from` / `starts_at` / `start_date`: items created after date/time
  - `created_at_gte`: items created on or after date/time
  - `created_at_lt` / `to` / `ends_at` / `end_date`: items created before date/time
  - `created_at_lte`: items created on or before date/time
- Status:
  - `completed=true|false`
  - `active=true` (`completed=false`) / `active=false` (`completed=true`)
- Pagination:
  - `page` (default: 1)
  - `per_page` (default: 40, max: 200)

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "project_todos": [
    {
      "id": 1,
      "project_id": 1,
      "title": "Migrate database indices",
      "meta_text": "High priority",
      "completed": false,
      "completed_at": null,
      "position": 1,
      "created_at": "2026-09-01T10:00:00.000Z",
      "updated_at": "2026-09-01T10:00:00.000Z"
    }
  ]
}
```

### `GET /api/projects/:project_id/project_todos/:id`

Fetches a single project todo.

### `POST /api/projects/:project_id/project_todos`

Creates a project todo.

**Params**: `title` (required), `meta_text`, `completed`, `completed_at`, `position`.

**Response** `201 Created`.

### `PATCH`/`PUT /api/projects/:project_id/project_todos/:id`

Updates a project todo.

**Response** `200 OK`.

### `DELETE /api/projects/:project_id/project_todos/:id`

Deletes a project todo. Returns `204 No Content`.

---

## Project Milestones

### `GET /api/projects/:project_id/project_milestones`

Lists milestones for a project. Supports date range filtering on `created_at`, active/inactive filtering, and pagination.

**Query Parameters:**
- Date range:
  - `created_at_gt` / `from` / `starts_at` / `start_date`: items created after date/time
  - `created_at_gte`: items created on or after date/time
  - `created_at_lt` / `to` / `ends_at` / `end_date`: items created before date/time
  - `created_at_lte`: items created on or before date/time
- Status:
  - `active=true|false`
- Pagination:
  - `page` (default: 1)
  - `per_page` (default: 40, max: 200)

**Response** `200`
```json
{
  "count": 1,
  "page": 1,
  "per_page": 40,
  "project_milestones": [
    {
      "id": 1,
      "project_id": 1,
      "title": "Discovery & framework alignment",
      "description": "Initial architecture validated",
      "icon": "✅",
      "active": true,
      "position": 1,
      "created_at": "2026-09-01T10:00:00.000Z",
      "updated_at": "2026-09-01T10:00:00.000Z"
    }
  ]
}
```

### `GET /api/projects/:project_id/project_milestones/:id`

Fetches a single project milestone.

### `POST /api/projects/:project_id/project_milestones`

Creates a project milestone.

**Params**: `title` (required), `description`, `icon`, `active`, `position`.

**Response** `201 Created`.

### `PATCH`/`PUT /api/projects/:project_id/project_milestones/:id`

Updates a project milestone.

**Response** `200 OK`.

### `DELETE /api/projects/:project_id/project_milestones/:id`

Deletes a project milestone. Returns `204 No Content`.

---

## Source Files

- Auth: [`app/controllers/api/base_controller.rb`](../app/controllers/api/base_controller.rb)
- Projects: [`app/controllers/api/projects_controller.rb`](../app/controllers/api/projects_controller.rb)
- Rooms: [`app/controllers/api/rooms_controller.rb`](../app/controllers/api/rooms_controller.rb)
- Messages: [`app/controllers/api/messages_controller.rb`](../app/controllers/api/messages_controller.rb)
- Actions: [`app/controllers/api/actions_controller.rb`](../app/controllers/api/actions_controller.rb)
- Decisions: [`app/controllers/api/decisions_controller.rb`](../app/controllers/api/decisions_controller.rb)
- Attention Items: [`app/controllers/api/attention_items_controller.rb`](../app/controllers/api/attention_items_controller.rb)
- Company Status Periods: [`app/controllers/api/company_status_periods_controller.rb`](../app/controllers/api/company_status_periods_controller.rb)
- Company Status Items: [`app/controllers/api/company_status_items_controller.rb`](../app/controllers/api/company_status_items_controller.rb)
- Project Users: [`app/controllers/api/project_users_controller.rb`](../app/controllers/api/project_users_controller.rb)
- Project All-Hands Takeaways: [`app/controllers/api/project_all_hands_takeaways_controller.rb`](../app/controllers/api/project_all_hands_takeaways_controller.rb)
- Project All-Hands Decisions: [`app/controllers/api/project_all_hands_decisions_controller.rb`](../app/controllers/api/project_all_hands_decisions_controller.rb)
- Project All-Hands Action Items: [`app/controllers/api/project_all_hands_action_items_controller.rb`](../app/controllers/api/project_all_hands_action_items_controller.rb)
- Project Knowledge Items: [`app/controllers/api/project_knowledge_items_controller.rb`](../app/controllers/api/project_knowledge_items_controller.rb)
- Project External Assets: [`app/controllers/api/project_external_assets_controller.rb`](../app/controllers/api/project_external_assets_controller.rb)
- Project ADRs: [`app/controllers/api/project_adrs_controller.rb`](../app/controllers/api/project_adrs_controller.rb)
- Project Knowledge Activities: [`app/controllers/api/project_knowledge_activities_controller.rb`](../app/controllers/api/project_knowledge_activities_controller.rb)
- Project Directory Items: [`app/controllers/api/project_directory_items_controller.rb`](../app/controllers/api/project_directory_items_controller.rb)
- Project Obsidian Notes: [`app/controllers/api/project_obsidian_notes_controller.rb`](../app/controllers/api/project_obsidian_notes_controller.rb)
- Project Bottlenecks: [`app/controllers/api/project_bottlenecks_controller.rb`](../app/controllers/api/project_bottlenecks_controller.rb)
- Project Todos: [`app/controllers/api/project_todos_controller.rb`](../app/controllers/api/project_todos_controller.rb)
- Project Milestones: [`app/controllers/api/project_milestones_controller.rb`](../app/controllers/api/project_milestones_controller.rb)
- Routes: [`config/routes.rb`](../config/routes.rb) (`namespace :api`)
- Tests: `test/controllers/api/*_test.rb`
