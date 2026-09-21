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
- `url` (string, required)
- `authentication` (string, required)
- `bearer_token` (string, optional)
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
- Presence on `name`, `transport`, `url`, `authentication`, `status`
- Length max 255 on string columns

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
- `status` and `authentication` are intentionally strings in this version (no enum constraint).
- `Mcp::Server` naming avoids conflict with existing top-level `Mcp` runtime module usage.
