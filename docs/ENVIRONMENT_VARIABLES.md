# Environment Variables

This project reads runtime configuration from environment variables. For local development, the expected pattern is a `.env` file in the app root. For production or deployment, environment values should be injected via the runtime environment, Docker `--env-file`, or a secret manager.

## Local development setup

Create a local `.env` file from the template and adjust the values to match your setup:

```bash
cp .env.example .env
```

The app uses these values at boot time and in the runtime services.

---

## Required and commonly used variables

| Variable | Required | Default / example | Purpose |
| --- | --- | --- | --- |
| `DEFAULT_ADMIN_NAME` | No | `Admin` | Default admin display name used on first run. |
| `DEFAULT_ADMIN_EMAIL` | No | `admin@pwrwork.local` | Initial admin email. |
| `DEFAULT_ADMIN_PASSWORD` | No | `pwrpassword` | Initial admin password. |
| `ENABLE_AI_CONFIG_PAGE` | No | `FALSE` | Enables the AI settings/config page. |
| `HERMES_BASE_URI` | Yes for real runtime | `http://127.0.0.1:8642` | Hermes API base URL. Also accepts legacy `BASE_URI`. |
| `HERMES_STATUS_URI` | No | `http://127.0.0.1:9119` | Hermes status endpoint. Also accepts legacy `STATUS_BASE_URI`. |
| `HERMES_DASHBOARD` | No | `true` | Enables the Hermes dashboard server. |
| `HERMES_DASHBOARD_HOST` | No | `0.0.0.0` | Bind address for the Hermes dashboard. |
| `HERMES_DASHBOARD_PORT` | No | `8080` | Port used by the Hermes dashboard. |
| `HERMES_API_KEY` | Yes for real runtime | none | API key for Hermes access. Also accepts `API_SERVER_KEY` and `API_KEY`. |
| `HERMES_MODEL` | No | `hermes` | Model name. Also accepts legacy `MODEL`. |
| `HERMES_DEFAULT_PROFILE` | No | `delegator` | Default Hermes profile. Also accepts legacy `BASE_HERMES_PROFILE`. |
| `HERMES_HTTP_TIMEOUT` | No | `60` | Request timeout in seconds. |
| `HERMES_MAX_ACTIVE_AGENTS` | No | `2` | Max concurrent agent actions. |
| `AI_TASK_DISPATCH_INTERVAL_SECONDS` | No | `1` | Polling interval for the task dispatch loop. |
| `EVENT_MERGE_SETTLE_SECONDS` | No | `1.5` | Delay before event dedupe/merge settles. |
| `EVENT_RECOVERY_MAX_AGE_SECONDS` | No | `900` | Maximum age for recovery processing. |
| `HERMES_EVENT_MAX_ATTACHMENTS` | No | `5` | Max attachments per outbound event. |
| `HERMES_EVENT_MAX_ATTACHMENT_BYTES` | No | `20971520` | Max attachment size in bytes. |
| `RESTART_TRIGGER_PATH` | No | `tmp/restart.txt` | Restart trigger file path. |
| `DISABLE_API_ROUTES` | No | `true` | Controls whether API routes are disabled. |
| `MCP_AUTH_TOKEN` | Yes when MCP auth is enabled | none | Shared secret for protected MCP routes. |
| `OUTPUT_MESSAGE_PROFILE` | No | `HERMES_DEFAULT_PROFILE` | Event output profile for messages. |
| `OUTPUT_AI_SETTING_PROFILE` | No | `HERMES_DEFAULT_PROFILE` | Event output profile for AI settings. |
| `OUTPUT_WORKSPACE_PROFILE` | No | `HERMES_DEFAULT_PROFILE` | Event output profile for workspace events. |
| `OUTPUT_EVENTS_URL` | Legacy only | none | Deprecated output event webhook URL. |
| `OUTPUT_EVENTS_TOKEN` | Legacy only | none | Deprecated shared secret for output events. |
| `VAPID_PUBLIC_KEY` | Yes for push notifications | none | Public Web Push key sent to browsers. |
| `VAPID_PRIVATE_KEY` | Yes for push notifications | none | Private Web Push key kept on the server. |
| `APP_VERSION` | No | `0` | Application version label. |
| `GIT_REVISION` | No | none | Git SHA used in app metadata and release info. |
| `RAILS_MASTER_KEY` | Yes in production if using credentials | none | Required when Rails encrypted credentials are used. |
| `RAILS_ENV` | No | `development` | Rails runtime environment. |
| `PORT` | No | `3000` | Application port. |
| `RAILS_MAX_THREADS` | No | app default | Puma thread count. |
| `RAILS_MIN_THREADS` | No | app default | Puma minimum thread count. |
| `WEB_CONCURRENCY` | No | app default | Web process concurrency. |
| `REDIS_URL` | Depends on deployment | none | Redis connection string. |
| `SENTRY_DSN` | No | none | Sentry DSN for production telemetry. |
| `SKIP_TELEMETRY` | No | blank | Set this to disable telemetry in production. |
| `DISABLE_SSL` | No | blank | Used to disable SSL assumptions in some deployment modes. |

---

## .env example

This is the current local template used by the repo:

```env
# Default first-run admin
DEFAULT_ADMIN_NAME=Admin
DEFAULT_ADMIN_EMAIL=admin@pwrwork.local
DEFAULT_ADMIN_PASSWORD=pwrpassword

# Sidebar feature flag
ENABLE_AI_CONFIG_PAGE=FALSE

# Hermes Agent Server Settings
HERMES_BASE_URI=http://127.0.0.1:8642
HERMES_STATUS_URI=http://127.0.0.1:9119
HERMES_DASHBOARD=true
HERMES_DASHBOARD_HOST=0.0.0.0
HERMES_DASHBOARD_PORT=8080
HERMES_API_KEY=your-hermes-api-key
HERMES_MODEL=hermes
HERMES_DEFAULT_PROFILE=delegator
HERMES_HTTP_TIMEOUT=60
HERMES_MAX_ACTIVE_AGENTS=2
AI_TASK_DISPATCH_INTERVAL_SECONDS=1

# Event dedupe and output settings
EVENT_MERGE_SETTLE_SECONDS=1.5
EVENT_RECOVERY_MAX_AGE_SECONDS=900
HERMES_EVENT_MAX_ATTACHMENTS=5
HERMES_EVENT_MAX_ATTACHMENT_BYTES=20971520
RESTART_TRIGGER_PATH=/triggers/restart

# Optional / compatibility
DISABLE_API_ROUTES=true
MCP_AUTH_TOKEN=replace-with-real-mcp-token

OUTPUT_MESSAGE_PROFILE=message_analyzer
OUTPUT_AI_SETTING_PROFILE=ai_settings
OUTPUT_WORKSPACE_PROFILE=workspace

# VAPID Web Push keys
VAPID_PUBLIC_KEY=replace-with-public-key
VAPID_PRIVATE_KEY=replace-with-private-key
```

---

## Docker usage

### Docker run with env file

```bash
docker run --rm \
  --env-file .env \
  -p 3000:3000 \
  pwrwork/space:latest
```

### Docker run with explicit values

```bash
docker run --rm \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=replace-me \
  -e HERMES_BASE_URI=http://host.docker.internal:8642 \
  -e HERMES_API_KEY=replace-me \
  -e MCP_AUTH_TOKEN=replace-me \
  -e VAPID_PUBLIC_KEY=replace-me \
  -e VAPID_PRIVATE_KEY=replace-me \
  pwrwork/space:latest
```

### Docker Compose

```yaml
services:
  web:
    image: pwrwork/space:latest
    env_file:
      - .env
    environment:
      RAILS_ENV: production
      PORT: 3000
    ports:
      - "3000:3000"
```

For Compose, `environment:` values override the same keys from `env_file` when both are present.

---

## VAPID key generation

This app uses Web Push notifications via VAPID. A valid P-256 key pair is required.

Use the included helper:

```bash
cd pwr
ruby script/admin/create-vapid-key
```

The script prints a matching private/public key pair. Example output:

```text
PRIVATE KEY : wKEaL1HZWcI9v3VCgLMJrzHqMHyJvMLV4hw8ZW5Ra5E=
PUBLIC KEY  : BMe_5yJnkAMotmQ7e6j4PHfKLAjv-d3-x_JrlZWJKOLJbkbVH-dSQ-IIPSyz8-QXUOHMVp0ykYX6lEo4j2PF4jM=
```

Then place them in `.env`:

```env
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
```

Keep the private key secret and never expose it in client-side code.

---

## Notes

- `.env` should remain local and untracked for development.
- In production, use a secret manager or injected environment values instead of committing secrets to source control.
- A few legacy variable names are still accepted for compatibility: `BASE_URI`, `STATUS_BASE_URI`, `API_SERVER_KEY`, `API_KEY`, `MODEL`, `BASE_HERMES_PROFILE`, `SPACE_EVENT_MERGE_SETTLE_SECONDS`, and `SPACE_EVENT_RECOVERY_MAX_AGE_SECONDS`.
- The application’s Docker image namespace is `pwrwork/space`, and the release export artifact is `space.zip`.
