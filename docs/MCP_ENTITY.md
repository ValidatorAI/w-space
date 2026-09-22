# MCP Entity Documentation

This document describes the MCP persistence model used to store reusable endpoint configuration for AI profile integrations.

## 1. What Is MCP?

In the persistence layer, MCP records represent configurable endpoint entries used by AI profiles. The runtime MCP tool/controller namespace remains under the `Mcp` module, while the database-backed model is `Mcp::Server` mapped to the `mcps` table.

Primary source files:
- `app/models/mcp/server.rb`
- `db/migrate/20260921090000_create_mcps.rb`

## 2. Database Schema

Table: `mcps`

Columns:
- `id` (bigint, primary key)
- `name` (string, required)
- `transport` (string, required)
- `url` (string, required at DB level)
- `authentication` (string, required at DB level)
- `bearer_token` (string, optional)
- `command` (string, optional)
- `args` (text, optional)
- `environment` (text, optional)
- `status` (string, required)
- `created_at` (datetime)
- `updated_at` (datetime)

Indexes:
- index on `name`

Schema reference:
- `db/schema.rb`

## 3. Rails Model

Model class:
- `Mcp::Server < ApplicationRecord`

Table mapping:
- `self.table_name = "mcps"`

Associations:
- `has_many :ai_profile_mcps, class_name: "AiProfileMcp", foreign_key: :mcp_id, dependent: :destroy`
- `has_many :ai_profiles, through: :ai_profile_mcps`

Scopes:
- `active` -> MCP rows where `status = "active"`

Validations:
- Presence on `name`, `transport`, `status`
- Conditional validations:
  - HTTP transport requires `url` and `authentication`
  - Bearer authentication requires `bearer_token`
  - stdio transport requires `command` and `args`
- Transport/auth/status inclusion checks against allowed constants
- Length max 255 on string columns

Normalization:

- `before_validation :normalize_transport_attributes` keeps fields consistent per transport:
  - stdio transport clears HTTP-only fields and forces `authentication` to `none`
  - HTTP transport clears stdio-only fields

## 4. Example Usage

Create an MCP entry:

```ruby
Mcp::Server.create!(
  name: "bonfire-main",
  transport: "http",
  url: "https://example.com/mcp",
  authentication: "bearer",
  bearer_token: "token-value",
  status: "active"
)
```

List active MCPs:

```ruby
Mcp::Server.active
```

## 5. Notes

- `bearer_token` is optional and can be null.
- `status`, `transport`, and `authentication` are string-based with model-level inclusion checks.
- `Mcp::Server` naming avoids conflict with existing top-level `Mcp` runtime module usage.

## 6. API Read Endpoints

MCP entities are available through read-only API endpoints:

- `GET /api/mcps`
- `GET /api/mcps/:id`

Authentication:

- Requests must include `Authorization: Bearer <OUTPUT_EVENTS_TOKEN>`.
- Token validation is enforced in `Api::BaseController`.

Response safety:

- Raw `bearer_token` is not returned.
- Raw `environment` is not returned.
- Metadata fields are returned instead:
  - `bearer_token_present`, `bearer_token_length`
  - `environment_present`, `environment_length`
