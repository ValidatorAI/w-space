# Testing Guide

This guide explains how to run tests in PWR locally, how to mirror CI behavior, and how to troubleshoot common failures.

## Overview

PWR uses Rails tests for unit/integration coverage and Selenium-based system tests for browser workflows.

Core commands:

```bash
bin/rails test
bin/rails test:system
bin/ci
```

## Test Suite Map

| Area | Path | Command | Purpose |
| --- | --- | --- | --- |
| Unit and integration tests | `test/models`, `test/services`, `test/controllers`, `test/jobs`, `test/lib`, `test/channels`, `test/helpers` | `bin/rails test` | Validate application logic and API behavior |
| System tests | `test/system` | `bin/rails test:system` | Validate end-to-end browser flows |
| Full local CI flow | `config/ci.rb` | `bin/ci` | Run setup, lint, security checks, tests, and seed validation |

## Prerequisites

Run from the repository root (`pwr`).

1. Install dependencies and setup app:

```bash
bin/setup --skip-server
```

2. Prepare test database:

```bash
bin/rails db:setup
```

3. Ensure Chrome/Chromium is available for system tests (headless Selenium driver).

## Quick Start

```bash
bin/rails test
bin/rails test:system
```

If test data is out of sync:

```bash
env RAILS_ENV=test bin/rails db:seed:replant
```

## Running Specific Tests

Run one file:

```bash
bin/rails test test/models/user_test.rb
```

Run one test by line number:

```bash
bin/rails test test/models/user_test.rb:42
```

Run one directory:

```bash
bin/rails test test/services
```

Run one system test file:

```bash
bin/rails test:system test/system/sending_messages_test.rb
```

Run one system test by line number:

```bash
bin/rails test:system test/system/sending_messages_test.rb:25
```

## CI Parity

GitHub CI currently runs separate jobs for scan, lint, test, and test_system. Local `bin/ci` is stricter in some areas and includes additional checks.

Recommended local parity sequence:

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

## Test Helpers and Conventions

Base test setup (`test/test_helper.rb`):

- Enables WebMock for non-system tests.
- Disables outbound network connections by default (`WebMock.disable_net_connect!`).
- Runs tests in parallel (`parallelize(workers: :number_of_processors)`).
- Loads all fixtures automatically (`fixtures :all`).

System test setup (`test/application_system_test_case.rb`):

- Uses Selenium with `headless_chrome`.
- Includes shared `SystemTestHelper` methods.

Useful helper methods in system tests:

- `sign_in(email_address, password = "secret123456")`
- `join_room(room)`
- `send_message(message)`

## Troubleshooting

### Database and setup failures

Symptoms:
- Missing tables, schema mismatches, or fixture/seed errors.

Fix:

```bash
bin/rails db:setup
env RAILS_ENV=test bin/rails db:seed:replant
```

### WebMock errors in non-system tests

Symptoms:
- Errors about blocked network calls.

Fix:
- Stub external requests explicitly in tests.
- Avoid unstubbed outbound HTTP in unit/integration tests.

### System test browser failures

Symptoms:
- Selenium cannot start browser or fails early.

Fix:
- Ensure Chrome/Chromium is installed.
- Re-run a single system test file first to isolate:

```bash
bin/rails test:system test/system/sending_messages_test.rb
```

### CI passes locally but fails in GitHub (or inverse)

Fix:
- Run the full CI parity sequence above.
- Verify Redis-dependent behavior where relevant.

## PR Testing Checklist

Before opening a PR:

- [ ] Added or updated tests for behavior changes.
- [ ] Ran targeted tests for touched files/features.
- [ ] Ran system tests for UI or workflow changes.
- [ ] Ran lint and security checks:
  - `bin/rubocop`
  - `bin/bundler-audit`
  - `bin/importmap audit`
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
- [ ] Ran `bin/ci` successfully.

## Related Docs

- `docs/contribution.md`
- `docs/security.md`
- `docs/ENVIRONMENT_VARIABLES.md`
- `README.md`
