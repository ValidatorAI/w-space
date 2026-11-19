# Security Remediation Plan for Ruby Dependency Findings

Date: 2026-11-18
Scope: Containerized Rails app dependency vulnerabilities reported in scan_report.txt

## Environment Constraint

- Do not run Docker build commands on this machine.
- Perform image build and vulnerability rescan on CI or a remote build host.
- Local validation is limited to source changes, lockfile updates, and diff review.

## 1. Executive Summary

The scan shows zero OS-level vulnerabilities in the Alpine image, but significant Ruby gem exposure in the application bundle:
- Total Ruby findings: 68
- Critical: 2
- High: 17
- Medium: 33
- Low: 6
- Unknown: 10

Primary risk comes from runtime gems used by the production app, especially Rack/Puma/concurrent-ruby chains.
Immediate priority is to reduce attack surface in production and patch critical/high gems.

## 2. First Step Decision

Decision: Yes, the first step should be implemented immediately.

First step:
- Exclude test gems from production image build by changing BUNDLE_WITHOUT from development to development:test in Dockerfile-alpine-dhio.

Why first:
- Removes avoidable vulnerable transitive gems that are only needed for test tooling.
- Reduces production bundle size and attack surface with low regression risk.
- Makes subsequent vulnerability reports cleaner and easier to prioritize.

## 3. Current High-Risk Dependencies

Direct or effectively runtime-critical:
- Puma pinned by Gemfile, current lock version in Gemfile.lock.
- Bcrypt in Gemfile, current lock version in Gemfile.lock.
- JWT pulled via web-push in Gemfile, current lock version in Gemfile.lock.
- Rack and Rack-session in Gemfile.lock.
- Concurrent-ruby in Gemfile.lock.

Notable vulnerable transitives:
- Addressable in Gemfile.lock.
- Crass in Gemfile.lock.
- Erb default gem in Gemfile.lock.

## 4. Remediation Strategy

### Phase A: Attack Surface Reduction
- Update production bundle exclusions in Dockerfile-alpine-dhio.
- Trigger CI or remote build pipeline.
- Run vulnerability scan in CI/remote environment to measure immediate drop in findings.

### Phase B: Critical and High Runtime Patching
- Raise or pin minimum safe versions in Gemfile where appropriate.
- Run targeted dependency updates for runtime gems first.
- Ensure Rails boot and web process still function through Procfile and bin/start-app.

Suggested minimum targets from scan:
- concurrent-ruby >= 1.3.7
- rack >= 3.2.8
- puma >= 7.2.2 or >= 8.0.3 if compatible
- bcrypt >= 3.1.22
- jwt >= 3.2.0
- addressable >= 2.9.1
- crass >= 1.0.8
- erb >= 6.0.4

### Phase C: Compatibility and Regression Validation
- Verify app startup path in bin/boot, Procfile, bin/start-app.
- Run app boot, DB prepare, request smoke tests, background worker smoke test.
- Confirm no breakage from Puma major updates and Rack behavior changes.

### Phase D: Repeat Scan and Triage Residuals
- Rebuild and rerun image scan in CI/remote environment.
- Classify remaining findings:
  - True runtime risk
  - Build-only or dev-only residuals
  - False positives or duplicated advisories
- Document accepted risk with expiration date if any finding cannot yet be upgraded.

## 5. Implementation Plan (Ordered)

1. Update production BUNDLE_WITHOUT in Dockerfile-alpine-dhio.
2. Trigger CI/remote image build and rerun scan.
3. Update Gem constraints in Gemfile for direct high-risk gems.
4. Perform targeted bundle update for critical/high runtime gems.
5. Trigger CI/remote image rebuild and rerun scan.
6. Execute smoke validation for app server and workers.
7. Record final vulnerability baseline and unresolved exceptions.

## 6. Acceptance Criteria

- Production image excludes test gems.
- No Critical findings remain in production runtime gems.
- High findings reduced to zero or documented with mitigation and deadline.
- App boots successfully and serves requests.
- Worker process starts and processes jobs.
- Updated scan report archived with before/after comparison.

## 7. Risks and Mitigations

- Risk: Puma major upgrade introduces behavior changes.
  - Mitigation: Start with latest compatible minor in current major, then move to secure major if needed with smoke tests.
- Risk: Rack updates impact middleware behavior.
  - Mitigation: Validate host/header handling and static file behavior in staging.
- Risk: Rails main branch dependency graph shifts frequently.
  - Mitigation: Pin critical gems explicitly and lock after successful validation.

## 8. Deliverables

- Updated dependency configuration in Gemfile.
- Updated production build config in Dockerfile-alpine-dhio.
- New vulnerability scan report showing reduction from baseline in scan_report.txt.
- Short remediation changelog with residual risk notes.
