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

<!-- Promoted (removed from this file): L-007 → CLAUDE.md "Git & Branching"; L-008 → CLAUDE.md "Authorization & Data Access"; L-006 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-009 → CLAUDE.md "Authorization & Data Access"; L-013 → CLAUDE.md "Correctness & Resilience Checklist: Every writer" -->
<!-- Lessons start below. Next ID: L-019 -->

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
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-005: Conditionally unmounting content leaked side effects it registered
- **Area:** React lifecycle, global state
- **Pattern:** Gated a subtree (error/not-found/forbidden state) so it unmounted mid-load. The unmounted subtree had registered a pending event in a global provider (a blocking loading overlay) with no cleanup, so the overlay kept swallowing clicks on the replacement UI.
- **Root cause:** Reviewed only what renders in the new state, not side effects owned by the subtree being removed.
- **Rule:** When adding a gate that unmounts content, list what that subtree registers in shared/global state (loading trackers, subscriptions, timers, listeners) and ensure it is cleared on every terminal path. Test that the cleanup fires exactly once per transition.
- **Check:** For each new conditional render that hides existing children, look for start/register/subscribe calls inside those children without a matching cleanup on that path.
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
- **Check:** For each new access-check function whose result comes from a query, confirm an integration test runs that query against real data, including that each role can run the query at all (a missing table permission is an error, not an empty result).
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-012: Ran a test runner outside the script that sets its environment
- **Area:** testing, tooling, data safety
- **Pattern:** Invoked the test runner directly instead of through the project's test script, skipping the environment flag that routes database access to the test instance; code that builds its own connection fell back to ambient shell credentials for a shared database.
- **Root cause:** Assumed the test config alone isolated every connection, without checking how application code picks its database or what credentials were already exported in the shell.
- **Rule:** Run tests through the project's own scripts, or reproduce their exact environment. When running a runner directly against a database, unset the production/shared connection variables for that command so any non-test connection fails closed.
- **Check:** Before running integration tests ad hoc, compare the command with the package script's environment, and confirm no shared-database credentials are exported in the shell that runs it.
- **Seen:** 1 (self-review, 2026-10)

### L-014: Reported a consumer gap without checking that the path runs
- **Area:** code review, data flow
- **Pattern:** Flagged that a remapped record would no longer join its partner record, but the step that produces the partner never ran for the inputs where the remap applies.
- **Root cause:** Traced the consumer of the changed value but not the orchestration that decides which steps run for which inputs.
- **Rule:** Before reporting a defect on a path, confirm from the orchestration (gates, flags, type checks) that both the producer and the consumer run for the inputs involved.
- **Check:** For each finding, cite the caller or gate showing the path is reachable in the scenario described; drop or downgrade it if you can't.
- **Seen:** 1 (self-review, 2026-10)

### L-015: Parser enforced different bounds per input representation
- **Area:** validation, types, persistence
- **Pattern:** A parser accepted a value as a number up to one bound but as a string only up to a smaller one. The value was written as a number, stored in a wide integer column, and read back as a string, so the parser rejected its own output.
- **Root cause:** Picked a string-length guard by hand instead of deriving both branches from one bound, and didn't test the write → store → read round trip.
- **Rule:** Give every input representation of a value the same bound, enforced by one shared check (e.g. `Number.isSafeInteger` after conversion). Test that each value the writer can emit is accepted again after a storage round trip, including drivers that return wide integers as strings.
- **Check:** For each parser in the diff that branches on `typeof`, compare the bounds each branch enforces, and look for a test that feeds the read-back form (e.g. `String(max)`) through it.
- **Seen:** 1 (pr-review, 2026-10)

### L-016: Compared counts from two layers that use different equality rules
- **Area:** authorization, data access, validation
- **Pattern:** Deduplicated input ids in application code with exact string equality, then required the database to return one row per id. The database compared the column type with its own equality rule (case-insensitive for that type), so two spellings of one id produced one row, the counts disagreed, and a valid request was denied.
- **Root cause:** Assumed the application's notion of "same value" matched the database's, without checking how the column type compares values.
- **Rule:** Before comparing an input count with a result count (or matching input values against returned values), put the input in the same canonical form the storage layer compares by (case, whitespace, numeric vs. string), then deduplicate. Test with two spellings of the same value.
- **Check:** For each `new Set(...)` or dedup in the diff whose size is compared with a query's row count, confirm the elements are normalized to the column type's equality first, and that a test sends differently cased or formatted duplicates.
- **Seen:** 1 (pr-review, 2026-10)

### L-017: A batched GraphQL access check fails entirely for a role that lacks one root field
- **Area:** authorization, GraphQL
- **Pattern:** Combined several root fields into one access-check query; for a role without select permission on one of them the whole query failed validation, turning every check for that role into a server error.
- **Root cause:** Assumed a missing permission returns empty rows instead of a validation error.
- **Rule:** In role-scoped GraphQL access checks, query only the root fields the decision needs, and treat a permission "field not found" for a root as "no visible rows" for that root. Test every role.
- **Check:** For each multi-root query run with a user's token, confirm every role that can reach it has select on every root, or that missing roots degrade to empty.
- **Seen:** 1 (pr-review, 2026-10)

### L-018: A security test passed because of an earlier guard, not the rule it names
- **Area:** testing, authorization
- **Pattern:** Tests named after a specific defence (e.g. "denies X even when Y") passed because an earlier check returned first, so the named rule was never executed; another test asserted only the query text for a protection that did not hold.
- **Root cause:** Checked the outcome, not which branch produced it.
- **Rule:** For each security test, make the fixture reach the rule under test (remove the earlier reasons to deny), and assert the observable effect rather than the query shape. Mutation-check it: disable the rule and confirm the test fails. An expected-failure test (`it.fails`, `xfail`) must fail only for the vulnerable outcome; assert today's behaviour explicitly instead, so unrelated errors fail loudly. Before saying a planned fix will make it pass, run the test's attack against the planned rule.
- **Check:** For each "denies/blocks…" test in the diff, find the first return that fires for its fixture; if it isn't the named rule, flag it. For each expected-failure test, list the ways it can throw; flag it if any isn't the vulnerability. Check that the planned fix actually blocks the test's exact attack.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)
