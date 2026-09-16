# Manual Test Checklist: Full W-Space System Behavior

## Test Run Metadata
- [ ] Environment: local / staging / production-like
- [ ] Build or commit:
- [ ] Tester:
- [ ] Date:
- [ ] Company/project under test:
- [ ] Rooms under test:
- [ ] Bot account under test:
- [ ] Participants ready: User A, User B
- [ ] Unique test tag prepared (example: FULL-QA-2026-09-16-01)

## Preconditions
- [ ] User A and User B are members of the target project and room.
- [ ] Bot is enabled and reachable in this environment.
- [ ] User B can be tested in both states:
- [ ] Disconnected from the room
- [ ] Connected and actively viewing the room
- [ ] MCP endpoint and background workers are running.
- [ ] Logging/observability access is available (app logs, jobs, output_events table).

## A. Messaging and Room Interactions
1. [ ] A1: User A posts a text message in a shared room.
Expected:
- Message appears immediately for User A.
- Message persists after refresh.

2. [ ] A2: User B receives the message in realtime while connected.
Expected:
- Message appears for User B without refresh.

3. [ ] A3: Message ordering check.
Expected:
- New messages appear in correct chronological order.

4. [ ] A4: Attachment and rich-text message check.
Expected:
- Supported attachments and formatting render correctly.

5. [ ] A5: Unread/read behavior.
Expected:
- Unread increments when User B is away.
- Unread clears when User B opens room.

## B. Private Room and Bot
1. [ ] B1: Create/open private room with User A and Bot only.
Expected:
- Room is accessible only to intended members.

2. [ ] B2: Send a prompt to bot in private room.
Expected:
- Bot should answer in the private room.

3. [ ] B3: Verify no cross-room leakage.
Expected:
- Bot response does not appear in unrelated rooms.
- Non-members cannot see this private conversation.

4. [ ] B4: Bot failure behavior.
Expected:
- If bot cannot answer, user sees clear error/fallback behavior.

## C. Knowledge and Project Context
1. [ ] C1: Knowledge items create/list/update/delete.
Expected:
- API/UI reflect all CRUD changes accurately.
- Active/inactive filtering works.

2. [ ] C2: Knowledge activities audit trail.
Expected:
- New activity records appear with correct actor, action, and ordering.

3. [ ] C3: External assets management.
Expected:
- External asset links are validated and persisted.
- Updates and deletes are reflected immediately.

4. [ ] C4: Directory items and obsidian notes lifecycle.
Expected:
- File-backed records can be created/updated.
- Deleting record also cleans up stored file when applicable.

## D. Action Items and Todos
1. [ ] D1: Project todo lifecycle.
Expected:
- Create/update/delete works.
- Completed and reopened states update correctly.

2. [ ] D2: All-hands action items lifecycle.
Expected:
- Create/update/delete works.
- Active/inactive and ordering behavior are correct.

3. [ ] D3: UI consistency for status cards.
Expected:
- UI cards match API state after updates.

## E. Approval Requests and Decisions
1. [ ] E1: Create approval request in room.
Expected:
- Approval card appears in room UI.
- Request is retrievable via room-scoped API.

2. [ ] E2: Resolve through decision endpoint.
Action:
- Use POST /api/rooms/:room_id/decisions with approve/confirm/deny/cancel.
Expected:
- Side effects are triggered:
- ApprovalRequestAction log record is created.
- Linked attention items are resolved.
- ADR may be created when applicable.
- Room UI card updates via realtime stream.

3. [ ] E3: Direct approval request status patch behavior.
Action:
- Directly update approval request status to resolved via PATCH/PUT.
Expected:
- Status updates and resolved_at may be set.
- Side effects are not triggered:
- No ApprovalRequestAction record.
- No linked attention auto-resolution.
- No ADR auto-creation.

## F. ADR Lifecycle
1. [ ] F1: ADR create/list/update/delete.
Expected:
- ADR records persist with identifier/title/status/file_path.
- Pagination and active filters work.

2. [ ] F2: ADR status transitions.
Expected:
- proposed/accepted/deprecated/superseded transitions behave correctly.

3. [ ] F3: Decision-linked ADR creation.
Expected:
- Decision approvals create ADR when policy/inputs apply.

## G. Output Events Delivery
1. [ ] G1: Eligible events are recorded.
Expected:
- output_events rows are created for eligible actions.

2. [ ] G2: Filtered events are excluded.
Expected:
- Non-emitting event types do not create output_events rows.

3. [ ] G3: Success delivery behavior.
Expected:
- 2xx downstream response marks event synced/completed.

4. [ ] G4: Retryable failure behavior.
Expected:
- timeout/5xx triggers retries up to configured limit.

5. [ ] G5: Non-retryable failure behavior.
Expected:
- 4xx leaves event unsynced for manual follow-up.

6. [ ] G6: Missing delivery URL behavior.
Expected:
- Delivery is skipped and warning is logged.

## H. MCP Agent Workflow and Reservations
1. [ ] H1: Session start and identity.
Action:
- Run macro_start_session with project_path, program, model, task_description.
Expected:
- Agent identity and credentials are returned.

2. [ ] H2: Polling and heartbeat loop.
Expected:
- poll_messages returns incremental updates.
- heartbeat refreshes liveness and renews reservations when enabled.

3. [ ] H3: Reservation conflict checks.
Expected:
- check_conflicts reports overlaps correctly.
- Exclusive reserve blocks overlapping exclusive requests from other agents.

4. [ ] H4: Reservation release.
Expected:
- Released files become reservable by other agents immediately.

## I. Security and Isolation
1. [ ] I1: Unauthorized room access.
Expected:
- Non-members cannot subscribe/post/read room content.

2. [ ] I2: API auth enforcement.
Expected:
- Missing/invalid auth is rejected with no state mutation.

3. [ ] I3: Tenant and project isolation.
Expected:
- Cross-project/company data access is denied.

4. [ ] I4: Input sanitization checks.
Expected:
- Dangerous payloads are escaped/sanitized and do not execute.

## J. Regression Smoke
1. [ ] J1: Rapid send/edit/delete sequence.
Expected:
- No duplicates, race artifacts, or stale UI states.

2. [ ] J2: Burst messaging and updates.
Expected:
- Messages/actions processed once and in order.

3. [ ] J3: Refresh/reconnect during active use.
Expected:
- State remains consistent after reconnect.

## Evidence Capture
- [ ] Screenshot: shared-room send and realtime receive
- [ ] Screenshot: private-room bot prompt and bot answer
- [ ] Screenshot: unread before and after room open
- [ ] API/log evidence: decision endpoint side effects created
- [ ] API/log evidence: direct status patch without side effects
- [ ] DB evidence: output_events success and retry/failure examples
- [ ] MCP logs: session start, heartbeat, reservations
- [ ] Notes: anomalies with timestamp + test case ID

## Exit Criteria (Critical Gates)
- [ ] Gate 1: Realtime messaging delivery and ordering pass.
- [ ] Gate 2: Bot answers in private room with no leakage.
- [ ] Gate 3: POST /api/rooms/:room_id/decisions triggers expected side effects.
- [ ] Gate 4: Direct PATCH/PUT resolved status on approval_requests does not trigger those side effects.
- [ ] Gate 5: Knowledge/todos/action items/ADR lifecycle checks pass.
- [ ] Gate 6: Output-events reliability checks pass.
- [ ] Gate 7: MCP lifecycle and reservation coordination pass.
- [ ] No Sev-1 or Sev-2 open defects.

## Final Sign-Off
- [ ] QA approved
- [ ] Product approved
- [ ] Engineering approved
- [ ] Ready for rollout
