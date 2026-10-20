# Coding Lessons Learned

Generic, root-cause lessons from reviews of code Claude wrote. Managed by the
"Lessons Learned" workflow in CLAUDE.md.

PUBLIC FILE: it is synced to a public repo. Every entry must pass the
Sanitization Rules in CLAUDE.md. No project, company, client, product, people,
paths, schema, endpoints, or copied code.

Entry format:

### L-NNN: <generic one-line title>
- **Area:** <e.g. authorization, validation, async, React hooks, testing, types>
- **Pattern:** <the generic mistake, described in neutral terms>
- **Root cause:** <the faulty assumption or skipped step that produced it>
- **Rule:** <what to do instead, stated as an imperative>
- **Check:** <a concrete way to detect it in a diff>
- **Seen:** <count> (<source: pr-review | self-review | user-feedback>, <YYYY-MM>; ...)

---

<!-- Promoted (removed from this file): L-007 → CLAUDE.md "Git & Branching"; L-008 → CLAUDE.md "Authorization & Data Access" -->
<!-- Lessons start below. Next ID: L-013 -->

### L-001: Added a parallel async path instead of reusing the existing one
- **Area:** async, data fetching/caching
- **Pattern:** Added a new refresh/revalidation call for a resource that an existing callback already revalidated, causing duplicate concurrent requests for the same cache key.
- **Root cause:** Fixed the symptom locally without tracing existing call sites that already handled the same resource.
- **Rule:** Before adding a new fetch, mutate, or revalidate call, search for existing call sites touching the same key/resource and extend or reuse them.
- **Check:** For each new fetch/mutate/revalidate call in the diff, search for other calls on the same key or resource; flag duplicates triggered by the same event.
- **Seen:** 1 (pr-review, 2026-10)

### L-002: Made an event handler async without a failure path
- **Area:** async, error handling, UX
- **Pattern:** Converted a handler to `async` and awaited `Promise.all(...)` with no try/catch, so a rejection became a silent unhandled rejection with no user feedback or retry.
- **Root cause:** Verified only the success path of the change.
- **Rule:** Every new or changed async handler needs an explicit catch that surfaces the failure (error state/toast, or typed error response) and, where sensible, a retry.
- **Check:** For each `async` function or new `await` in the diff, confirm a try/catch or an explicit caller-side catch exists and that the catch produces visible feedback.
- **Seen:** 1 (pr-review, 2026-10)

### L-003: Collapsed "unknown/error" into a confident negative
- **Area:** state modeling, null handling, testing
- **Pattern:** Coalesced an unresolved async value to a definite answer (`?? 0`, `exists = false` on request error), presenting "couldn't determine" as "confirmed zero / not found". Wrote tests asserting that behavior, which locked the bug in.
- **Root cause:** Modeled fetch results as a boolean or scalar instead of enumerating states, and conflated an access decision (hide content on failure) with a user-facing claim ("doesn't exist").
- **Rule:** Model fetch-derived state explicitly: loading / success / not-found / error. Never let a fallback value stand in for "unknown". Keep "should we render" separate from "what do we tell the user". Errors get their own message and retry.
- **Check:** Inspect every `??`, `||`, and default value applied to async or external data in the diff: is the fallback semantically different from "unknown"? Flag any test that asserts an error produces a negative result.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-004: Made a new state reachable without auditing its consumers
- **Area:** state modeling, rendering
- **Pattern:** Added handling for a new state in one place, but a value rendered alongside it (an optional ID interpolated into a URL) was undefined in that state, producing a broken link.
- **Root cause:** Changed a producer without tracing what each consumer renders in the newly reachable state.
- **Rule:** When a change makes a new state reachable, find every consumer of the values involved and check its behavior in that state. Prefer pure helpers that return `string | null` for derived URLs and render a link only when non-null.
- **Check:** For each new branch/state in the diff, list the values that can be undefined or null in it and search for their uses, especially in template strings, URLs, and hrefs.
- **Seen:** 1 (pr-review, 2026-10)

### L-005: Conditionally unmounting content leaked side effects it registered
- **Area:** React lifecycle, global state
- **Pattern:** Gated a subtree (error/not-found/forbidden state) so it unmounted mid-load. The unmounted subtree had registered a pending event in a global provider (a blocking loading overlay) with no cleanup, so the overlay kept swallowing clicks on the replacement UI.
- **Root cause:** Reviewed only what renders in the new state, not side effects owned by the subtree being removed.
- **Rule:** When adding a gate that unmounts content, list what that subtree registers in shared/global state (loading trackers, subscriptions, timers, listeners) and ensure it is cleared on every terminal path. Test that the cleanup fires exactly once per transition.
- **Check:** For each new conditional render that hides existing children, look for start/register/subscribe calls inside those children without a matching cleanup on that path.
- **Seen:** 1 (pr-review, 2026-10)

### L-006: Trusted static types for an external API response
- **Area:** types, external APIs, debugging
- **Pattern:** Read fields named by a declared TypeScript response type that didn't match the real payload's shape or meaning: values came back `undefined` (→ `NaN`/`0`, with two successive fixes failing for the same reason), or a field whose name suggested one identifier actually held a different one.
- **Root cause:** Treated a compile-time type, or a field's name, as proof of runtime shape and meaning; nothing validated it.
- **Rule:** When a value from an external response is wrong, or a design depends on what a field means, inspect a real captured payload and cross-check the value against its source of truth before building on it. Validate external responses at the boundary with a runtime schema, and fix stale types once confirmed.
- **Check:** For new reads of external response fields in the diff, confirm a runtime schema or verified sample backs the declared type, and for identifiers, that a sample value was matched against the entity it supposedly references.
- **Seen:** 2 (self-review, 2026-08; self-review, 2026-10)

### L-009: Row-level write check satisfiable by the row being written
- **Area:** authorization, row-level security
- **Pattern:** A permission's post-write check required "a membership row for me exists on the parent", while the role could update the membership table's foreign keys, so moving its own membership row to another parent satisfied the check and granted access.
- **Root cause:** Reviewed the filter/check expressions in isolation without asking whether the write itself can change the facts the check relies on.
- **Rule:** For any table that grants access (memberships, assignments, roles), deny writes to its foreign-key columns for the roles it scopes, and test that a role cannot reassign itself.
- **Check:** For each insert/update permission in the diff, list the columns the check depends on through relationships; flag any that are writable by the same role, especially on membership/assignment tables.
- **Seen:** 1 (pr-review, 2026-10)

### L-010: Structural policy test matched a required clause at any depth
- **Area:** testing, authorization
- **Pattern:** A test asserting "every permission rule requires clause X" searched the whole expression tree for X, so X under an unrelated relationship, under a negation/disjunction, or reached through a one-to-many relationship satisfied it without enforcing the intended scope. Through a to-many hop, X means "some related row qualifies", not "this row qualifies".
- **Root cause:** Wrote the matcher for the shapes that existed, not for the shapes an incorrect rule could take.
- **Rule:** Policy-lint tests must match the required clause only at the specific path that gives the scoping meaning: reject it under `not`/`or`/unrelated relationships, follow only single-row (to-one) relationships to reach it, and treat unknown keys as failing. Include negative fixtures for each bypass shape.
- **Check:** For each recursive matcher in a policy test, try writing a rule that passes the matcher but doesn't enforce the policy (including one that reaches the clause through a to-many relationship); if one exists, flag it.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-011: Authorization queries tested only against a mocked database
- **Area:** authorization, testing
- **Pattern:** Access-check helpers built from SQL joins were unit-tested with a mocked query function, so the tests checked the branching but never the joins and predicates that actually enforce access.
- **Root cause:** Treated the SQL as plumbing rather than as the security boundary itself.
- **Rule:** When the authorization decision is made in a query, add an integration test against a real database with seeded allowed/denied fixtures for each role, including inactive users and cross-tenant rows.
- **Check:** For each new access-check function whose result comes from a query, confirm an integration test runs that query against real data.
- **Seen:** 1 (pr-review, 2026-10)

### L-012: Ran a test runner outside the script that sets its environment
- **Area:** testing, tooling, data safety
- **Pattern:** Invoked the test runner directly instead of through the project's test script, skipping the environment flag that routes database access to the test instance; code that builds its own connection fell back to ambient shell credentials for a shared database.
- **Root cause:** Assumed the test config alone isolated every connection, without checking how application code picks its database or what credentials were already exported in the shell.
- **Rule:** Run tests through the project's own scripts, or reproduce their exact environment. When running a runner directly against a database, unset the production/shared connection variables for that command so any non-test connection fails closed.
- **Check:** Before running integration tests ad hoc, compare the command with the package script's environment, and confirm no shared-database credentials are exported in the shell that runs it.
- **Seen:** 1 (self-review, 2026-10)
