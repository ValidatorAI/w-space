# Deployment Runbook

This runbook describes how to deploy PWR using the Docker and Compose assets in this repository.

## Scope

In scope:
- Container image build and runtime deployment.
- Compose-based deployment with bundled Hermes and app services.
- Runtime validation, restart, and rollback basics.

Out of scope:
- External infrastructure provisioning (load balancers, DNS, managed databases).
- Secret-manager implementation details outside repository configs.

## Deployment Modes

Choose one mode based on your release workflow:

1. Build and run locally from repository source:
- Compose file: `docker-compose.build.yml`
- App image: `${APP_IMAGE:-pwrwork/space:local}`

2. Run from a prebuilt app image:
- Compose file: `docker-compose.hub.yml`
- App image: `pwrwork/space:latest`

3. Alpine image local build variant (optional):
- Compose file: `docker-compose.alpine.yml`
- App image: `pwrwork/space:alpine-local`

## Prerequisites

- Docker Engine and Docker Compose plugin.
- Repository checked out and commands run from `pwr` root.
- A deployment `.env` file with production-ready values.
- Open ports required by compose configuration:
  - `3000` (PWR app)
  - `8642` (Hermes API)
  - `8080` (Hermes dashboard, if enabled)

## 1) Prepare Environment and Secrets

Start from template:

```bash
cp .env.example .env
```

Set deployment-safe values at minimum:

- `RAILS_ENV=production`
- `SECRET_KEY_BASE=<strong-random-value>`
- `HERMES_API_KEY=<shared-hermes-key>`
- `MCP_AUTH_TOKEN=<strong-random-token>`
- `OUTPUT_EVENTS_TOKEN=<strong-random-token>`
- `VAPID_PUBLIC_KEY=<web-push-public-key>`
- `VAPID_PRIVATE_KEY=<web-push-private-key>`

Recommended:

- Keep `.env` private and untracked.
- Inject secrets via runtime environment or secret manager in production.

If needed, generate VAPID keys:

```bash
ruby script/admin/create-vapid-key
```

## 2) Pre-Deployment Checklist

Run in `pwr` root before release:

```bash
bin/ci
```

At minimum, ensure these pass:

```bash
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/rails test
bin/rails test:system
```

## 3) Deploy

### Option A: Build + deploy from source (`docker-compose.build.yml`)

```bash
docker compose -f docker-compose.build.yml up -d --build
```

This starts:
- `hermes` service from `nousresearch/hermes-agent:stable`
- `app` service built from repository `Dockerfile` (or `${APP_DOCKERFILE}`)

### Option B: Deploy prebuilt app image (`docker-compose.hub.yml`)

```bash
docker compose -f docker-compose.hub.yml pull
docker compose -f docker-compose.hub.yml up -d
```

This uses `pwrwork/space:latest` for the app service.

### Option C: Alpine app image variant (`docker-compose.alpine.yml`)

```bash
docker compose -f docker-compose.alpine.yml build
docker compose -f docker-compose.alpine.yml up -d
```

## 4) Verify Deployment

Check service status:

```bash
docker compose -f docker-compose.build.yml ps
```

Tail logs:

```bash
docker compose -f docker-compose.build.yml logs -f app hermes
```

Health checks:

```bash
curl http://localhost:3000/up
curl http://localhost:8642/health/detailed
```

If `DISABLE_API_ROUTES=false` and API routes are enabled, you can also verify API health:

```bash
curl -H "Authorization: Bearer ${OUTPUT_EVENTS_TOKEN}" http://localhost:3000/api/health
```

## 5) Operational Commands

Restart services:

```bash
docker compose -f docker-compose.build.yml restart
```

Restart only app:

```bash
docker compose -f docker-compose.build.yml restart app
```

Stop and remove containers (keep named volumes):

```bash
docker compose -f docker-compose.build.yml down
```

## 6) Data and Persistence

The app stores SQLite data in the named volume:

- `pwr-sqlite-data` mounted at `/rails/storage`

Hermes profile/state data is persisted in:

- `hermes-data`

Backup named volumes before risky releases.

## 7) Rollback

### Rollback for hub image deployment

1. Pin app image tag in `docker-compose.hub.yml` (or override image to a known-good tag).
2. Redeploy:

```bash
docker compose -f docker-compose.hub.yml pull
docker compose -f docker-compose.hub.yml up -d
```

### Rollback for source-built deployment

1. Checkout known-good commit.
2. Rebuild and redeploy:

```bash
docker compose -f docker-compose.build.yml up -d --build
```

3. Verify health endpoints and logs.

## 8) Common Failure Signals

- App unhealthy at `/up`: inspect app logs and confirm env secrets.
- Hermes unreachable: check `hermes` container state and `HERMES_BASE_URI` wiring.
- Auth failures on API/MCP: verify `OUTPUT_EVENTS_TOKEN` and `MCP_AUTH_TOKEN`.
- Worker/job issues: confirm Redis connectivity and queue processing paths.

For detailed local failure diagnosis, use `docs/troubleshooting.md`.

## Related Docs

- `docs/ENVIRONMENT_VARIABLES.md`
- `docs/getting-started.md`
- `docs/testing.md`
- `docs/security.md`
- `docs/troubleshooting.md`
- `docs/architecture-overview.md`
- `README.md`
