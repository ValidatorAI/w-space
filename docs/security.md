# Security Analysis Guide

This document defines the minimum security analysis process for PWR and its Hermes runtime dependency. It standardizes what to scan, how to run scans, how to report findings, and what still needs to be improved.

## Scope

In scope:
- PWR Rails application code and dependencies.
- Hermes container images used by PWR.
- PWR web attack surface through authenticated and unauthenticated routes.

Out of scope for this doc:
- Private disclosure channel workflow (not configured in this repository yet).
- Production infrastructure hardening details outside this repository.

## Required Security Analyses

| Tool | Target | Purpose | Current status |
| --- | --- | --- | --- |
| Trivy | Hermes images and PWR image | Container OS and package vulnerability analysis | Available as manual commands and existing output artifacts |
| OWASP ZAP | Running PWR app | DAST for route, auth, and response-level weaknesses | Available through ZAP plans and runner script |
| Brakeman | PWR Rails codebase | SAST for Rails-specific security issues | Enforced in CI and local CI script |

## Trivy Analysis (Hermes and PWR)

### 1) Hermes image scan

Run from the `pwr` directory:

```bash
cd pwr
mkdir -p security/reports

trivy image --severity HIGH,CRITICAL --ignore-unfixed \
  --format table \
  --output security/reports/trivy-hermes-ultra-hardened.txt \
  hermes:ultra-hardened

trivy image --format json \
  --output security/reports/trivy-hermes-ultra-hardened.json \
  hermes:ultra-hardened
```

### 2) PWR image scan

Build and scan PWR image:

```bash
cd pwr
mkdir -p security/reports

docker build -f Dockerfile -t pwrwork/space:local .

trivy image --severity HIGH,CRITICAL --ignore-unfixed \
  --format table \
  --output security/reports/trivy-pwr-space-local.txt \
  pwrwork/space:local

trivy image --format json \
  --output security/reports/trivy-pwr-space-local.json \
  pwrwork/space:local
```

If local Docker build is restricted, run the build and Trivy scan in CI or a remote build host and archive the same report artifacts.

### Trivy review convention

- Track findings by severity: CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN.
- Release gate target:
  - CRITICAL: must be 0.
  - HIGH: must be 0, or explicitly accepted with a mitigation and deadline.
- Keep before/after report pairs whenever image hardening changes.

## ZAP Analysis (Dynamic Web Security)

Primary entrypoint:

```bash
cd pwr
export ZAP_USER='test-admin@example.com'
export ZAP_PASS='test-password'
mkdir -p security/reports security/zap
zap.sh -cmd -newsession security/zap/scan.session -autorun security/zap/zap-plan.yaml
```

Use only a test account and test database.

### Example ZAP YAML structure

This is the expected structure for a project-local plan stored under `pwr/security/zap/`:

```yaml
env:
  contexts:
    - name: localhost-auth-safe
      urls:
        - "http://localhost:3000"
      authentication:
        method: form
        parameters:
          loginPageUrl: "http://localhost:3000/session/new"
          loginRequestUrl: "http://localhost:3000/session"
          loginRequestBody: "email_address={%username%}&password={%password%}"
      users:
        - name: testuser
          credentials:
            username: "${ZAP_USER}"
            password: "${ZAP_PASS}"

jobs:
  - type: requestor
    name: auth-check
  - type: spider
  - type: activeScan
  - type: report
```

### Which plan to use

- `security/zap/zap-plan-crawl.yaml`: safest first pass (passive/crawl oriented).
- `security/zap/zap-plan-auth.yaml`: authenticated bounded active scan (recommended default).
- `security/zap/zap-plan-all-routes.yaml`: broader seeded route coverage.

### ZAP review convention

- Treat High and Medium alerts as triage-required.
- Capture report artifact path in each vulnerability report.
- Re-run the same plan after a fix to verify closure.

## Brakeman Analysis (Rails SAST)

### Local runs

From `pwr` directory:

```bash
bin/brakeman
```

Strict CI-like run:

```bash
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

### CI coverage

- GitHub Actions scan job runs `bin/brakeman` in `.github/workflows/ci.yml`.
- Local CI script (`config/ci.rb`) runs Brakeman plus dependency audits.

### Ignore-file convention

`config/brakeman.ignore` may only contain findings with:
- A clear technical justification.
- Scope boundaries (why exploit path is blocked).
- A revalidation trigger (code path change, dependency update, or release audit).

## Vulnerability Reporting Convention (Public Flow)

This repository currently routes reports through public Discussions first.

Current references:
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/preapproved.md`
- `CONTRIBUTING.md`

### Reporting path

1. Open a public GitHub Discussion for the vulnerability.
2. Use the convention below in the title and body.
3. If maintainers approve and reproduction is confirmed, convert/promote to an issue using the same metadata.

### Title convention

`[SECURITY][SEV-<LEVEL>][<AREA>] <short summary>`

Examples:
- `[SECURITY][SEV-HIGH][AUTH] Session fixation after login`
- `[SECURITY][SEV-MEDIUM][MCP] Missing auth check on endpoint`

### Severity levels

- `SEV-CRITICAL`: active compromise or high-impact remote exploit.
- `SEV-HIGH`: exploitable weakness with major impact.
- `SEV-MEDIUM`: real vulnerability with moderate impact.
- `SEV-LOW`: limited impact or constrained exploitability.

### Required report fields

```markdown
## Summary
One paragraph describing the vulnerability.

## Affected area
Component, endpoint, file, and branch/commit if known.

## Severity
SEV-CRITICAL | SEV-HIGH | SEV-MEDIUM | SEV-LOW

## Reproduction steps
Exact numbered steps and required preconditions.

## Expected vs actual behavior
Short diff between intended and observed behavior.

## Impact
Confidentiality / Integrity / Availability impact and scope.

## Evidence
Logs, scan output paths, screenshots, request/response snippets.

## Proposed remediation
Code-level or config-level fix recommendation.

## Verification plan
How the fix will be tested (tool + command + success condition).
```

### Triage SLA convention

- Initial triage response: within 2 business days.
- Confirmed High/Critical findings: remediation plan within 5 business days.
- Fix verification: rerun the originating scan and attach new artifact.

## Remaining Security Analysis Backlog

The following work is still pending and should be tracked:

| Priority | Remaining analysis/work | Why it matters |
| --- | --- | --- |
| P1 | Add a dedicated first-party Trivy script for Hermes and PWR targets | Makes scans repeatable and reduces command drift |
| P1 | Add ZAP to CI as at least a scheduled non-blocking job | Turns manual DAST into continuous visibility |
| P1 | Align GitHub CI security checks with local `config/ci.rb` (gem audit + importmap audit) | Prevents local-only security checks |
| P2 | Create an explicit threat model document (auth, MCP, multi-tenant boundaries, background jobs) | Improves test coverage against realistic attack paths |
| P2 | Expand authz abuse-case DAST tests (forced browsing, IDOR, role boundary checks) | Reduces access-control regression risk |
| P2 | Add secret scanning (pre-commit and CI) | Detects accidental credential/token commits early |
| P3 | Replace default ZAP runner fallback credentials with required env-only input | Reduces accidental misuse of weak defaults |
| P3 | Formalize risk acceptance expiration policy for ignored findings | Prevents permanent silent exceptions |

## References

- `pwr/.github/workflows/ci.yml`
- `pwr/config/ci.rb`
- `pwr/bin/brakeman`
- `pwr/config/brakeman.ignore`
- `pwr/security-remediation-plan.md`
- `pwr/security/hardened-hermes-docker/vulnerability-summary.md`
- `pwr/security/hardened-hermes-docker/least-vulnerable-variant.md`
