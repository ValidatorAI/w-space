# AI Profile MCP Entity Documentation

This document describes the join model connecting AI profiles to MCP endpoint records.

## 1. What Is AiProfileMcp?

`AiProfileMcp` is the profile-to-MCP assignment entity. It controls whether a specific MCP integration is active for a specific AI profile.

Primary source files:
- `app/models/ai_profile_mcp.rb`
- `db/migrate/20260921090001_create_ai_profile_mcps.rb`

## 2. Database Schema

Table: `ai_profile_mcps`

Columns:
- `id` (bigint, primary key)
- `ai_profile_id` (bigint, required, foreign key)
- `mcp_id` (bigint, required, foreign key -> `mcps.id`)
- `active` (boolean, required, default: true)
- `created_at` (datetime)
- `updated_at` (datetime)

Indexes and constraints:
- Unique composite index on (`ai_profile_id`, `mcp_id`)
- Foreign key to `ai_profiles`
- Foreign key to `mcps`

Schema reference:
- `db/schema.rb`

## 3. Rails Model

Model class:
- `AiProfileMcp < ApplicationRecord`

Associations:
- `belongs_to :ai_profile`
- `belongs_to :mcp, class_name: "Mcp::Server"`

Scopes:
- `active` -> rows where `active = true`
- `inactive` -> rows where `active = false`

## 4. Example Usage

Assign an MCP to a profile:

```ruby
profile = AiProfile.first
mcp = Mcp::Server.first

AiProfileMcp.create!(ai_profile: profile, mcp: mcp)
```

Disable an assignment:

```ruby
assignment = AiProfileMcp.find_by!(ai_profile: profile, mcp: mcp)
assignment.update!(active: false)
```

Read profile MCPs:

```ruby
profile.mcps
```

## 5. Notes

- Only one row per `ai_profile_id` + `mcp_id` is allowed by the unique index.
- `active` defaults to true for newly-created assignments.
- This table follows the same join-table pattern as `ai_profile_tools` and `ai_profile_skills`.

## 6. API Read Endpoints

The profile-to-MCP assignment entity is available through read-only API endpoints:

- `GET /api/ai_profile_mcps`
- `GET /api/ai_profile_mcps/:id`

Optional index filters:

- `ai_profile_id`
- `mcp_id`

Authentication:

- Requests must include `Authorization: Bearer <OUTPUT_EVENTS_TOKEN>`.
- Token validation is enforced in `Api::BaseController`.

Response shape:

- Index returns `{ count, ai_profile_mcps: [...] }`.
- Show returns a single assignment object.
