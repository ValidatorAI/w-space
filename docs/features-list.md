# Features List by Page

This document lists the human-facing pages and sub-pages in PWR.
For each page, it captures:

- URL
- Main features on that page
- Why the page and those features exist

## Scope

Included:
- Web pages and sub-pages used by contributors and admins.
- Debug and utility pages that are accessed as page-like endpoints.

Excluded:
- API and MCP endpoint catalogs.

## Auth and Onboarding

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Sign in | `/session` | Email/password login form, rate-limit rejection handling, logout flow support | Provides the primary authentication entrypoint for workspace access |
| First run setup | `/first_run` | Initial workspace bootstrap, first admin setup, initial profile selection | Enables safe first-time initialization before normal access |
| Join by invite code | `/join/:join_code` | Invite-based user creation flow tied to join code | Supports controlled self-serve onboarding |
| Session transfer | `/session/transfers/:id` | Token-based session handoff/continuity | Supports session migration and continuity flows |

## Workspace Shell and Navigation

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Root resolver | `/` | Redirects to user-relevant destination (room/company home) | Gives users a smart landing path after authentication |
| Sidebar | `/users/me/sidebar` | Membership groups, projects, directs, prioritized room navigation | Provides global navigation context across the workspace |

## Account and User Pages

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Account settings | `/account/edit` | Account profile updates, user management, invite controls, branding controls | Centralizes account-level governance and configuration |
| Account custom styles | `/account/custom_styles/edit` | Workspace style customization controls | Supports account-level visual branding and theming |
| Bots list | `/account/bots` | List bot identities and access their management actions | Provides visibility into available bot collaborators |
| New bot | `/account/bots/new` | Create a new bot identity | Enables controlled expansion of bot participants |
| Edit bot | `/account/bots/:id/edit` | Update bot metadata and access state | Supports lifecycle management of bot identities |
| User page | `/users/:id` | User-facing profile shell for selected member | Provides direct access to a member profile surface |
| My profile | `/users/me/profile` | Personal profile details, direct/shared membership context | Lets users manage their own identity and context |
| My settings | `/users/me/settings` | User preferences/settings surface | Centralizes user-specific configuration |

## Company Pages

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Company home | `/users/me/company/home` | Attention categories, open/overdue/AI counters, quick ask input | Provides executive triage and action queue visibility |
| Company status | `/users/me/company/status` | Status-period view, priorities/progress/risks/dependencies | Supports portfolio-level status tracking and review |
| Company settings | `/users/me/company/settings` | Organization profile, invite controls, membership management, AI integration controls | Enables workspace-wide governance and administration |
| Add user modal | `/users/me/company/settings/add-user` | In-context user invitation form | Speeds up team growth without leaving settings flow |

## AI Admin Pages

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| AI admin home | `/users/me/company/ai-admin` | AI profile list, restart bridge/Hermes actions, config reset actions | Provides central operations page for AI configuration lifecycle |
| General AI settings | `/users/me/company/ai-admin/general-ai-settings` | Create/update/delete global AI settings | Centralizes runtime/provider-level AI configuration |
| MCPs list | `/users/me/company/ai-admin/mcps` | MCP server inventory and management entrypoints | Controls tool-server connectivity and availability |
| New MCP | `/users/me/company/ai-admin/mcps/new` | MCP creation form | Adds new MCP integrations safely |
| Edit MCP | `/users/me/company/ai-admin/mcps/:id/edit` | MCP update form | Maintains existing MCP integrations |
| Tools | `/users/me/company/ai-admin/tools` | Global tool listing and enable/disable controls | Controls workspace-wide tool exposure |
| Skills | `/users/me/company/ai-admin/skills` | Skill catalog view and management actions | Maintains skill inventory and operational readiness |
| New skill | `/users/me/company/ai-admin/skills/new` | Skill creation form | Introduces new reusable capabilities |
| Edit skill | `/users/me/company/ai-admin/skills/:id/edit` | Skill update form and metadata controls | Keeps skills current and aligned to usage |
| Learn skill page | `/users/me/company/ai-admin/skills/learn` | Skill learning request/learning workflow | Supports adding skills from operational demand |
| New profile | `/users/me/company/ai-admin/profiles/new` | Profile creation form | Defines new AI behavior profiles |
| Profile details | `/users/me/company/ai-admin/profiles/:id` | Per-profile settings and assignment toggles for tools/skills/MCPs | Enables profile-specific behavior composition |

## Project Pages

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| New project | `/users/me/company/projects/new` | Project creation with membership/channel setup inputs | Provides a structured project initialization flow |
| Project overview | `/users/me/company/projects/:id/overview` | Metrics, objectives, contributors, channels/resources, attention summaries | Gives a single cockpit view of project state |
| Project status | `/users/me/company/projects/:id/status` | Bottlenecks, todos, decisions, knowledge status cards | Supports delivery-health monitoring and alignment |
| Project all-hands | `/users/me/company/projects/:id/all-hands` | Meeting-oriented workspace for project takeaways/actions/decisions | Enables synchronous team/project coordination |
| Meeting detail | `/meeting/:id` | Active meeting display and participation view | Supports session-based all-hands execution |
| Project knowledge | `/users/me/company/projects/:id/knowledge` | Knowledge surface for notes, assets, ADRs, directory and activity | Consolidates long-lived project context and evidence |
| Knowledge file view | `/users/me/company/projects/:id/knowledge/file` | File-focused knowledge rendering/sub-view | Allows focused review of a selected knowledge artifact |

## Rooms and Messaging Pages

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Room page | `/rooms/:id` | Conversation tabs, context rails, decisions/artifacts views, live stream context | Acts as the primary collaboration workspace |
| Room anchored message view | `/rooms/:id/@:message_id` | Opens room view anchored to a specific message | Enables precise message-centric navigation and review |
| New open room | `/rooms/opens/new` | Open room creation form | Supports lightweight channel creation |
| Edit open room | `/rooms/opens/:id/edit` | Open room metadata editing | Maintains open-room structure over time |
| New closed room | `/rooms/closeds/new` | Closed/private room creation form with participant controls | Supports restricted collaboration contexts |
| Edit closed room | `/rooms/closeds/:id/edit` | Closed room metadata and participant updates | Maintains secure room membership and metadata |
| New direct room | `/rooms/directs/new` | Direct conversation creation flow | Supports focused one-to-one or direct communications |
| Edit direct room | `/rooms/directs/:id/edit` | Direct room settings update view | Maintains direct channel metadata and membership behavior |
| Room settings | `/rooms/:room_id/settings` | Room membership, bots, privacy and settings controls | Provides room-level administration |
| Room involvement | `/rooms/:room_id/involvement` | Personal room involvement controls | Lets users manage personal engagement/visibility state |
| Project edit (rooms namespace) | `/rooms/projects/:id/edit` | Project-level structural actions (archive/unarchive/delete, channel actions) | Centralizes project structure administration |
| Project users settings | `/rooms/projects/:project_id/users_settings` | Project membership management panel/modal | Enables controlled user and bot membership updates |
| Search | `/searches` | Global search input, filters, results and ask flow | Provides cross-workspace retrieval and discovery |

## Debug and Diagnostics Pages

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Debug dashboard | `/debug` | High-level debug views for project/topic/tool call contexts | Supports admin investigation and diagnostics |
| Debug topic | `/debug/topic/:id` | Topic-specific detail and relationship analysis | Enables deep topic-state investigation |
| Debug message | `/debug/message/:id` | Message-specific diagnostic view | Supports message-level forensic analysis |
| Debug output events | `/debug/output_events` | Output-event listing and inspection | Provides observability into event pipeline behavior |
| Hermes status | `/debug/hermes_status` | Hermes availability and status view | Confirms integration health and runtime readiness |

## Utility Pages and Endpoints

| Page | URL | Features | Why this page exists |
| --- | --- | --- | --- |
| Web manifest | `/webmanifest` | PWA metadata delivery for install-capable clients | Supports installable web app behavior |
| Service worker | `/service-worker` | Service worker script delivery | Supports PWA runtime behavior |
| QR code | `/qr_code/:id` | QR image generation from encoded URL value | Supports sharing/access workflows requiring QR surfaces |
| Health check | `/up` | Application liveness endpoint | Enables platform/runtime health verification |

## Route Notes (Ambiguous or Non-Canonical Page Surfaces)

- `resources :messages` generates page-like routes such as `/messages/new`, but message creation is generally handled in room context and there is no dedicated canonical standalone page flow.
- Open/closed room show routes can resolve through canonical room display behavior, so `/rooms/:id` remains the main collaboration page.
- Some routes are primarily action or stream surfaces (for example refresh/stream endpoints) rather than standalone pages and are intentionally not listed as primary pages.
