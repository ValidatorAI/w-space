# Troubleshooting Guide

This guide helps contributors diagnose and fix common local development and test failures in PWR.

## Fast Triage Checklist

Run from the `pwr` directory and verify basics first:

```bash
cp .env.example .env
bin/setup
bin/dev
bundle exec resque-pool
curl http://localhost:3000/up
```

If the health check fails, continue with the sections below.

## 1) Setup Fails (`bin/setup`)

### Symptom: setup exits immediately with `RAILS_ENV is production; bailing out`

Cause:
- Setup blocks production mode by design.

Fix:
- Unset or change `RAILS_ENV` before running setup.

```bash
unset RAILS_ENV
bin/setup
```

### Symptom: setup asks for `gum` or exits because it cannot install it

Cause:
- `bin/setup` requires `gum` and only auto-installs via `pacman` or `brew`.

Fix:
- Install `gum` manually for your platform, then re-run setup.

```bash
bin/setup
```

### Symptom: setup fails on `mise` not found

Cause:
- `bin/setup` requires `mise` to install runtime tools.

Fix:
- Install `mise`, then rerun setup.

```bash
bin/setup
```

### Symptom: setup cannot start Redis

Cause:
- Redis is not running, Docker is unavailable, or port 6379 is occupied.

Fix:
- Start or create the expected Redis container, or run your local Redis server.

```bash
docker start pwrwork-redis
# or, if container does not exist:
docker run -d --name pwrwork-redis -p 6379:6379 redis:7

bin/setup
```

## 2) Database Issues

### Symptom: missing tables, pending migrations, or schema mismatch

Fix:

```bash
bin/rails db:prepare
```

If local state is badly out of sync:

```bash
bin/rails db:setup
```

If you intentionally need a full reset:

```bash
bin/setup --reset
```

### Symptom: test data/seed mismatches in test runs

Fix:

```bash
env RAILS_ENV=test bin/rails db:seed:replant
```

## 3) App Boot and Runtime Issues

### Symptom: app does not boot cleanly with `bin/dev`

Cause:
- Boot path depends on `bin/start-app`, which clears stale PID and prepares DB.

Fix:
- Run startup path directly to isolate boot failures.

```bash
bin/start-app
```

Then return to normal multi-process startup:

```bash
bin/dev
```

### Symptom: health endpoint fails

Fix:
- Confirm web process is running, then retry health check.

```bash
curl http://localhost:3000/up
```

## 4) Redis and Background Jobs

### Symptom: jobs enqueue but do not process

Cause:
- Worker process is not running.

Fix:
- Start worker in a separate terminal.

```bash
bundle exec resque-pool
```

### Symptom: Redis connectivity errors at runtime

Fix:
- Ensure Redis is running and then restart app and worker.

```bash
docker start pwrwork-redis
bin/dev
bundle exec resque-pool
```

## 5) Test Failures

### Symptom: non-system tests fail due to blocked network calls

Cause:
- `WebMock.disable_net_connect!` is enabled in non-system tests.

Fix:
- Stub external HTTP calls in tests.
- Avoid unstubbed outbound HTTP in unit/integration tests.

### Symptom: system tests fail to launch browser

Cause:
- System tests require Selenium with headless Chrome/Chromium.

Fix:
- Install Chrome/Chromium and re-run a single system test first.

```bash
bin/rails test:system test/system/sending_messages_test.rb
```

### Symptom: hard-to-debug failures in full suite

Fix:
- Narrow scope and run one file or one line.

```bash
bin/rails test test/models/user_test.rb
bin/rails test test/models/user_test.rb:42
bin/rails test:system test/system/sending_messages_test.rb:25
```

## 6) CI Parity Mismatch (`passes local, fails CI`)

Run the same local parity sequence used in current docs:

```bash
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/rails test
bin/rails test:system
env RAILS_ENV=test bin/rails db:seed:replant
bin/ci
```

If parity still differs, re-check DB state and Redis/worker availability.

## 7) Asset and Dependency Security Checks

### Symptom: dependency security checks fail

Fix:

```bash
bin/bundler-audit
bin/importmap audit
```

### Symptom: Brakeman fails locally

Fix:

```bash
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## 8) Diagnostics Commands

Use these commands during triage:

```bash
bin/setup
bin/start-app
bin/dev
bundle exec resque-pool
bin/rails db:prepare
bin/rails db:setup
env RAILS_ENV=test bin/rails db:seed:replant
rails log:clear tmp:clear
curl http://localhost:3000/up
```

## When to Escalate

Escalate after you have run the relevant section commands and can provide:

- Exact failing command.
- Error output.
- What you already tried from this guide.
- Whether the issue appears only in local runs or also in `bin/ci`.

For security-related troubleshooting, continue in `docs/security.md`.
For contributor workflow expectations, use `docs/contribution.md`.

## Related Docs

- `docs/getting-started.md`
- `docs/testing.md`
- `docs/security.md`
- `docs/ENVIRONMENT_VARIABLES.md`
- `README.md`
