# PWR Contribution Guide

This guide explains how to contribute to PWR effectively, from feature ideas to merged pull requests.

It is intentionally practical and optimized for contributors who want to ship reliable changes with minimal review friction.

## Contribution Principles

- Be clear before coding: align on the problem and expected outcome.
- Keep changes small and reviewable.
- Always include tests for behavior changes.
- Update documentation for user-visible or operator-visible changes.
- Communicate early when blocked.

## Where to Start

PWR currently uses a discussion-first model.

1. For feature requests, open a Discussion first.
2. For uncertain bugs (no reliable reproduction), open a Discussion first.
3. For reproducible bugs, open an Issue.
4. For approved work, open a Pull Request.

Repository references:
- `CONTRIBUTING.md`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/preapproved.md`

## Requesting a Feature

Before implementation, submit a feature proposal in Discussion with:

- Problem statement: what is currently painful.
- Proposed solution: expected behavior and rough API/UX shape.
- Scope: what is in and out.
- Alternatives considered.
- Risk notes: migrations, compatibility, performance, security.

### Feature Proposal Template

```markdown
## Problem
What user/developer/operator problem are we solving?

## Proposed behavior
What should happen after this feature exists?

## Scope
In scope:
- ...
Out of scope:
- ...

## Acceptance criteria
1. ...
2. ...
3. ...

## Risks and mitigation
- Risk: ...
- Mitigation: ...
```

## Solving a Feature (Implementation Flow)

1. Confirm the feature is approved (Discussion or linked Issue).
2. Create a branch from `main`.
3. Implement in small logical commits.
4. Add tests that fail before and pass after your change.
5. Update docs when behavior/config/API changes.
6. Run local quality checks.
7. Open PR with a clear description and links to Discussion/Issue.

### Branch Naming Convention

Use one of these patterns:

- `feature/<short-topic>`
- `fix/<short-topic>`
- `docs/<short-topic>`
- `chore/<short-topic>`

Examples:
- `feature/mcp-output-profiles`
- `fix/sidebar-auth-check`
- `docs/security-guide`

## Testing Requirements

At minimum, run tests for what your change touches.

Recommended commands (from `pwr`):

```bash
bin/setup --skip-server
bin/rails test
bin/rails test:system
```

Quality and security checks:

```bash
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

Full local CI path:

```bash
bin/ci
```

### Test Policy

- Bug fix: include a regression test.
- New feature: include tests for the happy path and at least one failure/edge case.
- UI or behavior changes: include/adjust system tests where relevant.
- Security-sensitive changes: include a negative test for rejected/blocked behavior.

## Commit Convention

Use clear, imperative commit messages.

Preferred subject format:

`<type>(<scope>): <summary>`

Where `type` is one of:
- `feat`
- `fix`
- `docs`
- `test`
- `refactor`
- `chore`
- `security`

Examples:

- `feat(mcp): add workspace profile fallback`
- `fix(projects): prevent unsafe knowledge file resolution`
- `docs(contribution): add testing and PR checklist`

### Commit Message Rules

- Subject line: around 50 characters preferred, keep concise.
- Use imperative mood ("add", "fix", "remove").
- Add a body when context is needed: why, trade-offs, migration notes.
- Wrap body around 72 characters when possible.
- Keep each commit logically coherent.

## Pull Request Convention

### PR Title

Use the same pattern as commit subject when possible:

`<type>(<scope>): <summary>`

### PR Description Must Include

- What changed.
- Why it changed.
- How it was tested (exact commands).
- Links to Discussion/Issue.
- Screenshots or logs when helpful.
- Any follow-up work not included.

### PR Size and Structure

- Prefer small PRs focused on one logical change.
- Split unrelated work into separate PRs.
- Mark early work as Draft.

### Example PR Body

```markdown
## Summary
- Added ...
- Updated ...

## Why
This addresses ...

## Links
- Discussion: #...
- Issue: #...

## Testing
- `bin/rails test`
- `bin/rubocop`
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`

## Notes
- Follow-up task: ...
```

## Review and Collaboration Expectations

- Be respectful and specific in feedback.
- Request changes with actionable guidance.
- Prefer evidence (failing test, logs, reproducible steps) over opinion.
- Respond to review in batches and summarize what was changed.
- If you disagree, explain trade-offs and propose alternatives.

## Security and Sensitive Changes

For security-relevant changes, follow:

- `docs/security.md`

If your change affects auth, permissions, input validation, file paths, or secrets, include:

- threat/risk summary in PR,
- explicit test evidence for rejection/blocked paths,
- note on backward-compatibility impact.

## Common Reasons PRs Slow Down

- No linked discussion/issue for non-trivial work.
- Missing tests or weak test coverage.
- Missing docs for behavior changes.
- Very large PR with unrelated changes.
- Unclear commit/PR messages.

