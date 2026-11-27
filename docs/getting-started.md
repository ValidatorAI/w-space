# Getting Started

This guide covers the fastest path to run PWR locally, verify it is healthy, and run your first tests.

## Overview

PWR is a Rails app with Redis-backed background processing. A typical local loop is:

1. Configure `.env`
2. Run `bin/setup`
3. Start web and workers
4. Check health endpoint
5. Run tests

## Prerequisites

- Ruby and Bundler installed
- SQLite available
- Redis available, or Docker installed so setup can start Redis for you
- Run all commands from the `pwr` project root

## 1) Configure Environment

Create your local environment file:

```bash
cp .env.example .env
```

Default first-run admin from `.env.example`:

- Email: `admin@pwrwork.local`
- Password: `pwrpassword`

For full variable reference, see `docs/ENVIRONMENT_VARIABLES.md`.

## 2) Initial Setup

Run setup:

```bash
bin/setup
```

What this does:

- installs dependencies
- prepares the database
- clears temp/log files
- can start Redis via Docker when Redis is not already running and Docker is available

## 3) Start the Application

Terminal 1 (web app):

```bash
bin/dev
```

Terminal 2 (workers):

```bash
bundle exec resque-pool
```

Then open:

```text
http://localhost:3000
```

## 4) Verify Health

```bash
curl http://localhost:3000/up
```

A successful response indicates the app is up.

## 5) Run Your First Tests

Run unit/integration tests:

```bash
bin/rails test
```

Run system tests:

```bash
bin/rails test:system
```

Run local CI flow:

```bash
bin/ci
```

## Common Commands

```bash
cp .env.example .env
bin/setup
bin/dev
bundle exec resque-pool
curl http://localhost:3000/up
bin/rails test
bin/rails test:system
bin/ci
```

## Troubleshooting

### Setup fails on missing packages

Re-run setup after installing missing OS packages, then run:

```bash
bin/setup
```

### Redis connection errors

- Re-run `bin/setup`.
- If Docker is installed, setup can create/start a local Redis container automatically.

### Background jobs not processing

Make sure worker process is running in a separate terminal:

```bash
bundle exec resque-pool
```

### Health check fails

Confirm web server is running (`bin/dev`) and retry:

```bash
curl http://localhost:3000/up
```

### Test failures on first run

Re-run setup and then retry tests:

```bash
bin/setup
bin/rails test
bin/rails test:system
```

## Related Docs

- `README.md`
- `docs/ENVIRONMENT_VARIABLES.md`
- `docs/testing.md`
- `docs/security.md`
- `docs/contribution.md`
