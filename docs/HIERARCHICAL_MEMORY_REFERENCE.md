# Bonfire Hierarchical Memory Reference

A company-rooted memory path map for Bonfire entities and relationships.

All memory paths in this document start with:

- /company/[company_id]/...

This memory structure is intentionally user-facing and navigation-friendly. Runtime/API paths may differ and are mapped in the compatibility section.

## Path Notation

- Placeholders use square brackets, for example [project_id].
- Use [project_id_or_slug] where slug lookup is supported.
- Use canonical category keys for attention subtypes.

## Root Namespace

- /company/[company_id]

## Company-Rooted Hierarchy

### Company Context

- /company/[company_id]/home
- /company/[company_id]/settings
- /company/[company_id]/users
- /company/[company_id]/users/[user_id]
- /company/[company_id]/users/[user_id]/settings

### Projects (Primary Collaboration Boundary)

- /company/[company_id]/projects
- /company/[company_id]/projects/[project_id_or_slug]
- /company/[company_id]/projects/[project_id]/users
- /company/[company_id]/projects/[project_id]/users/[user_id]
- /company/[company_id]/projects/[project_id]/rooms
- /company/[company_id]/projects/[project_id]/knowledge
- /company/[company_id]/projects/[project_id]/all-hands
- /company/[company_id]/projects/[project_id]/status
- /company/[company_id]/projects/[project_id]/adrs
- /company/[company_id]/projects/[project_id]/todos
- /company/[company_id]/projects/[project_id]/milestones
- /company/[company_id]/projects/[project_id]/bottlenecks

### Rooms (Room-First Runtime Contract)

- /company/[company_id]/rooms
- /company/[company_id]/rooms/[room_id]
- /company/[company_id]/rooms/[room_id]/threads
- /company/[company_id]/rooms/[room_id]/messages
- /company/[company_id]/rooms/[room_id]/messages/[message_id]
- /company/[company_id]/rooms/[room_id]/messages/[message_id]/attachment
- /company/[company_id]/rooms/[room_id]/approval_requests
- /company/[company_id]/rooms/[room_id]/approval_requests/[approval_request_id]
- /company/[company_id]/rooms/[room_id]/actions
- /company/[company_id]/rooms/[room_id]/decisions

### Users

- /company/[company_id]/users
- /company/[company_id]/users/[user_id]
- /company/[company_id]/users/[user_id]/projects
- /company/[company_id]/users/[user_id]/rooms
- /company/[company_id]/users/[user_id]/attention
- /company/[company_id]/users/[user_id]/settings

### Company Status

- /company/[company_id]/status
- /company/[company_id]/status/periods
- /company/[company_id]/status/periods/[period_id]
- /company/[company_id]/status/periods/current
- /company/[company_id]/status/periods/by-slug/[slug]
- /company/[company_id]/status/items
- /company/[company_id]/status/items/[item_id]
- /company/[company_id]/status/periods/[period_id]/items

### Approvals and Attention

- /company/[company_id]/approvals/requests/[approval_request_id]
- /company/[company_id]/rooms/[room_id]/approval_requests/[approval_request_id]
- /company/[company_id]/attention/items
- /company/[company_id]/attention/items/[attention_item_id]
- /company/[company_id]/users/[user_id]/attention/items/[attention_item_id]
- /company/[company_id]/projects/[project_id]/attention/items/[attention_item_id]

Attention subtypes (domain-specific categories):

- decisions_waiting
- blockers
- outcomes_review
- mentions
- material_changes
- ai_confirm
- knowledge_proposals

Category normalization note:

- Canonical category keys follow AttentionItem::CATEGORIES, for example decisions_waiting.
- If an external payload uses singular variants such as decision_waiting, normalize to the canonical plural key before lookup.

Subtype-oriented attention paths:

- /company/[company_id]/attention/categories/decisions_waiting/items
- /company/[company_id]/attention/categories/blockers/items
- /company/[company_id]/attention/categories/outcomes_review/items
- /company/[company_id]/attention/categories/mentions/items
- /company/[company_id]/attention/categories/material_changes/items
- /company/[company_id]/attention/categories/ai_confirm/items
- /company/[company_id]/attention/categories/knowledge_proposals/items
- /company/[company_id]/users/[user_id]/attention/categories/[attention_category]/items/[attention_item_id]
- /company/[company_id]/projects/[project_id]/attention/categories/[attention_category]/items/[attention_item_id]

### Knowledge and Decisions

- /company/[company_id]/knowledge/items/[knowledge_item_id]
- /company/[company_id]/projects/[project_id]/knowledge/items/[knowledge_item_id]
- /company/[company_id]/projects/[project_id]/external-assets/[asset_id]
- /company/[company_id]/projects/[project_id]/directory-items/[directory_item_id]
- /company/[company_id]/projects/[project_id]/obsidian-notes/[obsidian_note_id]
- /company/[company_id]/projects/[project_id]/knowledge-activities/[activity_id]
- /company/[company_id]/decisions
- /company/[company_id]/projects/[project_id]/decisions
- /company/[company_id]/projects/[project_id]/adrs/[adr_id]

Knowledge subdomains (domain-specific resource families):

- knowledge_items (curated project knowledge records)
- external_assets (links and references; internal or external source type)
- directory_items (project file-tree content)
- obsidian_notes (imported or linked Obsidian knowledge)
- knowledge_activities (knowledge audit and activity feed)
- adrs (architectural decision records)

Subtype-oriented knowledge paths:

- /company/[company_id]/projects/[project_id]/knowledge/items/[knowledge_item_id]
- /company/[company_id]/projects/[project_id]/knowledge/items/by-badge/[badge]
- /company/[company_id]/projects/[project_id]/knowledge/external-assets/[asset_id]
- /company/[company_id]/projects/[project_id]/knowledge/external-assets/source/[source_type]
- /company/[company_id]/projects/[project_id]/knowledge/directory-items/[directory_item_id]
- /company/[company_id]/projects/[project_id]/knowledge/obsidian-notes/[obsidian_note_id]
- /company/[company_id]/projects/[project_id]/knowledge/activities/[activity_id]
- /company/[company_id]/projects/[project_id]/knowledge/adrs/[adr_id]

## API Compatibility Mapping

These mappings translate company-rooted memory paths to currently implemented API routes.

### Core Mappings

- /company/[company_id]/projects -> /api/projects
- /company/[company_id]/projects/[project_id_or_slug] -> /api/projects/[project_id_or_slug]
- /company/[company_id]/rooms -> /api/rooms
- /company/[company_id]/rooms/[room_id] -> /api/rooms/[room_id]
- /company/[company_id]/rooms/[room_id]/threads -> /api/rooms/[room_id]/threads
- /company/[company_id]/rooms/[room_id]/messages -> /api/rooms/[room_id]/messages
- /company/[company_id]/rooms/[room_id]/messages/[message_id] -> /api/rooms/[room_id]/messages/[message_id]
- /company/[company_id]/rooms/[room_id]/approval_requests -> /api/rooms/[room_id]/approval_requests
- /company/[company_id]/rooms/[room_id]/approval_requests/[approval_request_id] -> /api/rooms/[room_id]/approval_requests/[approval_request_id]
- /company/[company_id]/rooms/[room_id]/actions -> /api/rooms/[room_id]/actions
- /company/[company_id]/rooms/[room_id]/decisions -> /api/rooms/[room_id]/decisions

### Status and Attention Mappings

- /company/[company_id]/status/periods -> /api/company_status_periods
- /company/[company_id]/status/periods/[period_id] -> /api/company_status_periods/[period_id]
- /company/[company_id]/status/periods/current -> /api/company_status_periods/current
- /company/[company_id]/status/items -> /api/company_status_items
- /company/[company_id]/status/items/[item_id] -> /api/company_status_items/[item_id]
- /company/[company_id]/attention/items -> /api/attention_items
- /company/[company_id]/attention/items/[attention_item_id] -> /api/attention_items/[attention_item_id]

### Project Resource Mappings

- /company/[company_id]/projects/[project_id]/users -> /api/projects/[project_id]/users
- /company/[company_id]/projects/[project_id]/users/[user_id] -> /api/projects/[project_id]/users/[user_id]
- /company/[company_id]/projects/[project_id]/knowledge/items -> /api/projects/[project_id]/knowledge_items
- /company/[company_id]/projects/[project_id]/external-assets -> /api/projects/[project_id]/external_assets
- /company/[company_id]/projects/[project_id]/adrs -> /api/projects/[project_id]/adrs
- /company/[company_id]/projects/[project_id]/knowledge-activities -> /api/projects/[project_id]/knowledge_activities
- /company/[company_id]/projects/[project_id]/directory-items -> /api/projects/[project_id]/directory_items
- /company/[company_id]/projects/[project_id]/obsidian-notes -> /api/projects/[project_id]/obsidian_notes
- /company/[company_id]/projects/[project_id]/bottlenecks -> /api/projects/[project_id]/project_bottlenecks
- /company/[company_id]/projects/[project_id]/todos -> /api/projects/[project_id]/project_todos
- /company/[company_id]/projects/[project_id]/milestones -> /api/projects/[project_id]/project_milestones

## Relationship Rules

- Project is the main ownership boundary for collaboration artifacts.
- Room is the primary runtime contract for messaging and approval workflows.
- Message IDs are globally unique, so flat lookups can work without room or project path context.
- Approval requests belong to a room and can optionally attach to a message in that room.
- Room threading is hierarchical via parent-child room links.
- Some rooms are not project-backed, for example direct rooms.
- Company-level home and status views are derived and user-centric, not a standalone Company model.

## Common Memory Lookups

### Find all messages in a room

1. Memory path: /company/[company_id]/projects/[project]/rooms/[room]/messages
2. API path: /api/rooms/[room_id]/messages

### Resolve a specific approval card

1. Memory path: /company/[company_id]/projects/[project]/rooms/[room]/approval-requests/[approval_request_id]
2. API path: /api/rooms/[room_id]/approval_requests/[approval_request_id]

### Navigate company status period

1. Memory path: /company/[company_id]/status/[period]
2. Resolved memory path: /company/[company_id]/status/periods/[period_id_or_slug]
3. API path: /api/company_status_periods/[period_id_or_slug]

### Locate a user attention item

1. Memory path: /company/[company_id]/users/[user_id]/attention/[attention_item_id]
2. Resolved memory path: /company/[company_id]/users/[user_id]/attention/items/[attention_item_id]
3. API path: /api/attention_items/[attention_item_id]

### List attention items by subtype

1. Memory path: /company/[company_id]/users/[user_id]/attention/decisions_waiting
2. Resolved memory path: /company/[company_id]/users/[user_id]/attention/categories/decisions_waiting/items
3. API path: /api/attention_items?category=decisions_waiting&user_id=[user_id]

### Browse project knowledge by subdomain

1. Memory path: /company/[company_id]/projects/[project]/knowledge/external-assets
2. Resolved memory path: /company/[company_id]/projects/[project_id]/knowledge/external-assets
3. API path: /api/projects/[project_id]/external_assets

## Source-of-Truth Pointers

- API contract: docs/API_REFERENCE.md
- Route topology: config/routes.rb
- Project ownership semantics: docs/PROJECT_ENTITY.md
- Company home and status modeling: docs/company_home_data_model.md
- Messaging lifecycle: docs/MESSAGING_ARCHITECTURE.md
- Core entities:
  - app/models/project.rb
  - app/models/room.rb
  - app/models/user.rb
  - app/models/message.rb
  - app/models/approval_request.rb
  - app/models/attention_item.rb
  - app/models/company_status_period.rb
  - app/models/project_knowledge_item.rb
  - app/models/project_external_asset.rb
  - app/models/project_knowledge_activity.rb
  - app/models/project_adr.rb
