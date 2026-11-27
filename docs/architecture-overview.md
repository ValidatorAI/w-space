# Architecture Overview

This document gives a contributor-focused overview of PWR architecture: how the application is structured, how runtime processes interact, where data and access boundaries live, and which quality/security controls protect changes.

## Scope

In scope:
- Rails application architecture and code organization.
- Runtime process topology for local and CI-compatible development.
- Data, authentication, API, MCP, and realtime boundaries.
- Integration points with Hermes and background processing.

Out of scope:
- Production infrastructure hardening details outside this repository.
- External platform operations not represented in `pwr` source code.

## System Context

PWR is a Rails-based collaborative workspace where humans and AI agents coordinate in shared project and room contexts.

Primary actors:
- Human users in the web UI.
- Bot users and automated agents.
- Background workers processing async and periodic jobs.
- Hermes as an external model/tool gateway.

Primary interaction surfaces:
- Browser UI routes and controllers.
- Realtime channels for room and message updates.
- Token-protected API and MCP endpoints.

## Codebase Structure

Core directories and responsibilities:

- `app/controllers`: web, API, and MCP request handling.
- `app/models`: domain entities such as rooms, messages, users, sessions, reservations, and project records.
- `app/channels`: ActionCable realtime connection and room streams.
- `app/jobs`: asynchronous processing and event dispatch jobs.
- `app/services`: integration and application services (including Hermes configuration).
- `config`: environment, routes, queue, scheduling, and CI orchestration config.
- `db`: schema and migrations.
- `bin`: setup and runtime scripts.
- `test`: unit/integration/system tests and helpers.

## Runtime and Process Topology

The process model is defined in `Procfile`:

- `web`: Rails server via `thrust` and `bin/start-app`.
- `redis`: local Redis process.
- `workers`: `resque-pool` for background jobs.

Startup flow:

1. `bin/setup` installs dependencies, prepares database, and can start Redis via Docker fallback.
2. `bin/dev` starts local development runtime.
3. `bin/start-app` removes stale PID, runs `db:prepare`, then starts Rails server.

Health endpoint:

- `GET /up` (also used by runtime health checks).

## Data Architecture

Database:
- SQLite is the default persistence engine across development, test, and production environment configs in this repository.
- Local DB files are under `storage/db/`.

Representative domain areas from schema:
- Identity and access: users, sessions, memberships.
- Collaboration: rooms, messages, room-read state.
- Orchestration: tasks, output events, tool call logs.
- Governance and project context: projects, approvals, decisions, topics, knowledge and attention records.

## Authentication and Access Boundaries

Session-based web auth:
- Login path is handled by `SessionsController`.
- Successful login creates/resumes session state and writes signed cookie `session_token`.
- Web requests are protected through shared authentication concern.

API and MCP token boundaries:
- API controllers enforce bearer-token authentication (`OUTPUT_EVENTS_TOKEN`).
- MCP controller enforces bearer-token authentication (`MCP_AUTH_TOKEN`).
- MCP surface is exposed through JSON-RPC style endpoints (`/mcp`, `/action-mcp`, `/read-mcp`, `/knowledge-mcp`, `/config-mcp`, `/task-mcp`).

## Async and Realtime Architecture

Background processing:
- ActiveJob uses Resque in production config.
- Worker pool is managed by `resque-pool` with concurrency from `config/resque-pool.yml`.

Scheduled jobs:
- Recurring maintenance jobs are defined in `config/recurring.yml`.
- Includes file reservation cleanup and output-event dispatch reconciliation.

Realtime:
- ActionCable connection resolves current user from signed session cookie.
- Room subscriptions are scoped to rooms the current user belongs to.
- Message broadcasts propagate unread/read updates through channel events.

## External Integrations

Hermes integration:
- Hermes base/status URIs, model/profile defaults, timeouts, and dispatch behavior are configured in `app/services/hermes/configuration.rb` through environment variables.
- Async output-event jobs call Hermes-oriented dispatch paths.

MCP tooling integration:
- MCP tool registry is exposed via controller methods for tool listing and tool invocation.
- Scope-specific endpoints split action/read/knowledge/config/task interactions.

## Quality and Security Controls

Local quality gate flow:
- `config/ci.rb` orchestrates setup, linting, security checks, tests, and seed validation.
- Includes RuboCop, bundler-audit, importmap audit, Brakeman, Rails tests, and system tests.

GitHub CI workflow:
- Separate jobs for scan, lint, tests, and system tests.
- CI test jobs provide Redis service and run DB setup + test commands.

Security analysis posture:
- Security runbook and review standards are documented in `docs/security.md`.
- Current baseline includes Trivy, OWASP ZAP, and Brakeman conventions.

## Request and Event Flow Summary

Web interaction flow:

1. User authenticates via session endpoint.
2. Browser requests route to Rails controllers.
3. Model changes emit broadcasts for room/message realtime updates.
4. Background jobs handle deferred processing.

Agent/tool flow:

1. External caller sends token-authenticated request to API or MCP endpoint.
2. Controller validates token and request payload.
3. Domain logic updates project/room/task/knowledge records.
4. Output events are processed asynchronously and may dispatch to Hermes.

## Related Docs

- `docs/getting-started.md`
- `docs/testing.md`
- `docs/troubleshooting.md`
- `docs/security.md`
- `docs/contribution.md`
- `docs/ENVIRONMENT_VARIABLES.md`
- `README.md`
