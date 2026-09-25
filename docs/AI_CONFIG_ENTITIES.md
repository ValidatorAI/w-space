# AI Config Entities And API Routes

This document lists all entities used by the AI Config page, subpages, and child sections, and maps them to the read-only API routes.

## Authentication

All routes listed here are under `/api` and require:

- `Authorization: Bearer <OUTPUT_EVENTS_TOKEN>`

Validation is enforced by `Api::BaseController`.

## 1. Core AI Config Entities

- `AiProfile`
  - Used by AI Config profile list and profile edit page.
  - Routes:
    - `GET /api/ai_profiles`
    - `GET /api/ai_profiles/:id`
- `AiSetting`
  - Used by General AI Settings page.
  - Routes:
    - `GET /api/ai_settings`
    - `GET /api/ai_settings/:id`
- `Mcp::Server`
  - Used by MCP list/add/edit pages.
  - Routes:
    - `GET /api/mcps`
    - `GET /api/mcps/:id`
- `Tool`
  - Used by Tools page and profile Tools section.
  - Routes:
    - `GET /api/tools`
    - `GET /api/tools/:id`
- `Skill`
  - Used by Skills page and profile Skills section.
  - Routes:
    - `GET /api/skills`
    - `GET /api/skills/:id`

## 2. Child Assignment Entities

These entities power profile child sections for per-profile enable/disable state.

- `AiProfileTool`
  - Used by profile Tools section.
  - Routes:
    - `GET /api/ai_profile_tools`
    - `GET /api/ai_profile_tools/:id`
  - Optional filters:
    - `ai_profile_id`
    - `tool_id`

- `AiProfileSkill`
  - Used by profile Skills section.
  - Routes:
    - `GET /api/ai_profile_skills`
    - `GET /api/ai_profile_skills/:id`
  - Optional filters:
    - `ai_profile_id`
    - `skill_id`

- `AiProfileMcp`
  - Used by profile MCPs section.
  - Routes:
    - `GET /api/ai_profile_mcps`
    - `GET /api/ai_profile_mcps/:id`
  - Optional filters:
    - `ai_profile_id`
    - `mcp_id`

## 3. Response Safety Rules

To reduce leakage of secrets and sensitive free-text content, these fields are redacted in API responses:

- `AiProfile`
  - Raw `soul` is omitted.
  - Metadata returned: `soul_present`, `soul_length`.
- `Mcp::Server`
  - Raw `bearer_token` is omitted.
  - Raw `environment` is omitted.
  - Metadata returned:
    - `bearer_token_present`, `bearer_token_length`
    - `environment_present`, `environment_length`
- `Skill`
  - Raw `skill_text` is omitted.
  - Metadata returned: `skill_text_present`, `skill_text_length`.

## 4. Notes

- These are read-only API routes (`GET` + `GET all`) for AI Config entities.
- AI Admin web routes under `/users/:user_id/company/ai-admin` are separate UI endpoints and are not replaced by these API routes.
