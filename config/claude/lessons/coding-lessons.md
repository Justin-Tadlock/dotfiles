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

<!-- Promoted (removed from this file): L-007 → CLAUDE.md "Git & Branching"; L-008 → CLAUDE.md "Authorization & Data Access"; L-006 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-009 → CLAUDE.md "Authorization & Data Access"; L-013 → CLAUDE.md "Correctness & Resilience Checklist: Every writer"; L-003 → CLAUDE.md "Correctness & Resilience Checklist: Unknown is not negative"; L-011 → CLAUDE.md "Authorization & Data Access"; L-018 → CLAUDE.md "Correctness & Resilience Checklist: Testability"; L-014 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-027 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-028 → CLAUDE.md "Correctness & Resilience Checklist: Matching pipelines" -->
<!-- Lessons start below. Next ID: L-030 -->

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

### L-012: Ran a test runner outside the script that sets its environment
- **Area:** testing, tooling, data safety
- **Pattern:** Invoked the test runner directly instead of through the project's test script, skipping the environment flag that routes database access to the test instance; code that builds its own connection fell back to ambient shell credentials for a shared database.
- **Root cause:** Assumed the test config alone isolated every connection, without checking how application code picks its database or what credentials were already exported in the shell.
- **Rule:** Run tests through the project's own scripts, or reproduce their exact environment. When running a runner directly against a database, unset the production/shared connection variables for that command so any non-test connection fails closed.
- **Check:** Before running integration tests ad hoc, compare the command with the package script's environment, and confirm no shared-database credentials are exported in the shell that runs it.
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

### L-019: Derived role-access lists from code names instead of the authoritative role set
- **Area:** authorization
- **Pattern:** Grouped roles into access tiers by what their names suggested, and enumerated "all roles" from a code enum that was missing a role present in the database; one role got write access it shouldn't have, a deprecated role stayed fully privileged, and a new role was locked out of every guarded route.
- **Root cause:** Treated the code's role enum and role names as the specification, without reconciling them against the stored role table and the product's stated rules for each role.
- **Rule:** Before writing role tiers, list every role in the authoritative store (DB/IdP), get each role's intended read/write scope confirmed, and fail closed for any role not explicitly placed. Never use "all values of the enum" as an allow-list unless the enum is verified complete.
- **Check:** For each role list or `Object.values(<RoleEnum>)` in the diff, compare against the stored role set; confirm a test covers every role (including deprecated and newly added ones) for both read and write.
- **Seen:** 1 (pr-review, 2026-10)

### L-020: Async completion callback acted on whatever UI was current, not the UI that started it
- **Area:** async, React state, UX
- **Pattern:** A submit handler closed/reset a shared modal or selection when its request resolved, but the user could dismiss the originating UI while the request was pending and open a new instance, so the stale completion closed and reset the new one.
- **Root cause:** Treated the completion callback's target as fixed for the request's lifetime without checking whether the user could replace it mid-flight.
- **Rule:** For any side effect that runs after an await (close, reset, navigate, clear selection), either block replacing the originating UI until the request settles, or capture a session/instance token at submit and apply the effect only if it still matches. Test the interleaving.
- **Check:** For each `onClose`/`reset`/state-clear call after an `await` in the diff, ask whether the user can dismiss and reopen (or switch) that UI while the request is pending; if so, confirm a guard and a test exist.
- **Seen:** 1 (pr-review, 2026-10)

### L-021: Changed a server boundary's contract without auditing clients that bypass the shared helper
- **Area:** validation, API contracts, error handling
- **Pattern:** Added stricter input bounds and value normalization to an endpoint and improved error formatting in the shared client helper, but another client called the endpoint directly: it pre-transformed a field past the new bound, persisted the raw (un-normalized) value that a stricter downstream reader rejected, and kept showing the transport error instead of the server's message.
- **Root cause:** Audited callers of the helper, not every caller of the endpoint, and didn't trace what each client does to a field before sending it or with it afterwards.
- **Rule:** When changing an endpoint's validation, normalization or error shape, search for every request to that endpoint (not just helper usages). For each, check the transformations applied before sending against the new bounds, persist the server-normalized value rather than the raw input, and route errors through the shared formatter.
- **Check:** For each tightened bound or normalization in the diff, search for the endpoint path across the client code; for each hit, compare what it sends and stores with the new contract.
- **Seen:** 1 (pr-review, 2026-10)

### L-022: A row cap was applied before the filters that decide eligibility
- **Area:** data access, authorization
- **Pattern:** An access check fetched candidate rows with a limit and then filtered them in application code (deleted, owner, visibility), so rows that would grant access beyond the cap were never considered.
- **Root cause:** Picked the limit for the expected row count, without checking which filters ran before it and which after.
- **Rule:** Push every eligibility filter into the query before the limit. If anything still has to be filtered in code, page until found or exhausted, with a hard cap that fails closed.
- **Check:** For each limited query in the diff, check whether its results are filtered further in code. If so, flag it.
- **Seen:** 1 (pr-review, 2026-10)

### L-023: Error handling classified failures from only the first hop of a multi-step request
- **Area:** async, error handling, UX
- **Pattern:** A flow made an authorized API call and then fetched the resource it pointed to. The caller mapped "not found" using the HTTP client's error type, but the second hop threw a plain `Error`, so a missing resource after a successful first hop showed an unrelated generic/network message.
- **Root cause:** Wrote the status-based branch for the first request's error shape without listing which other steps can produce the same condition with a different error type.
- **Rule:** When a caller branches on failure kind, list every step that can produce that kind, have each throw a typed error preserving the status, and classify through one shared helper rather than a client-library-specific check at the call site. Test each step's failure separately.
- **Check:** For each `isXError(error) && status === N` branch in the diff, trace every awaited step in the called function; flag any step that can fail with the same meaning but throws a different error type.
- **Seen:** 1 (pr-review, 2026-10)

### L-024: Validated a request's host but let the HTTP client follow redirects
- **Area:** security, SSRF, secrets handling
- **Pattern:** A guard checked that a URL pointed at an allowed host before sending a request that carried a secret header and a sensitive body, but the HTTP client followed redirects automatically. A redirect could send the custom header (only standard credential headers are stripped across origins) and, on 307/308, the body to a host the guard never saw.
- **Root cause:** Treated the URL passed to the client as the only destination, without checking the client's redirect behavior.
- **Rule:** When a host/URL allow-list protects a request carrying secrets or privileged payloads, disable or reject redirects (e.g. `redirect: 'error'` / `maxRedirects: 0`), or re-validate every hop manually. Keep the guard and the request in one helper so every call goes through both.
- **Check:** For each host/URL allow-list check in the diff, find the request it guards and confirm redirects are refused or each hop is re-checked.
- **Seen:** 1 (pr-review, 2026-10)

### L-025: Matched an incoming name against a cached copy instead of the live value
- **Area:** data access, caching, identity
- **Pattern:** Resolved incoming names to records by a locally cached copy of an external system's name, while another flow updated the live local record's name first, so lookups missed until the next sync and created duplicates.
- **Root cause:** Listed the writers of the cache, not every writer of the value the cache mirrors.
- **Rule:** When resolving by a mirrored value, list every writer of both the mirror and the live value; match against both (treating conflicts as ambiguous) or update them together.
- **Check:** For each lookup on a synced/cached column in the diff, search for writes to the corresponding live column; flag any path that updates one without the other.
- **Seen:** 1 (pr-review, 2026-10)

### L-026: Per-file random counters for fixture IDs in a shared test database
- **Area:** testing, integration
- **Pattern:** Each test file started its own counter at a random offset for unique-keyed fixture IDs. Files run in parallel against one database whose rows persist, so the ranges could overlap and fail on the primary key intermittently.
- **Root cause:** Treated a random start as uniqueness without considering that the module state is per file while the database is shared.
- **Rule:** Allocate fixture values that must be unique across test files from the shared store (a database sequence created during test setup), not module-level counters or random values.
- **Check:** For each `Math.random()` or module-level counter feeding a unique column in test helpers, flag it if more than one test file can insert into that table.
- **Seen:** 1 (pr-review, 2026-10)

### L-029: Hid a persistent write inside a function used as a lookup/mapper
- **Area:** separation of concerns, data access, testability
- **Pattern:** Added a database write (linking a newly resolved record) inside a function named and called as a pure resolver. It ran once per batch from several call sites, so callers could not see the side effect, and the resolve logic could not be tested without the write.
- **Root cause:** Put the write where the resolved value first became available, without checking how many callers invoke that function or whether they expect it to be read-only.
- **Rule:** Keep resolve/map functions free of writes. Return what needs persisting (e.g. `{ items, toLink }`) and let the orchestrating caller do the write once, or name the function after the write it performs.
- **Check:** For each new insert/update/upsert in the diff, look at the enclosing function's name and callers; flag it if the name reads as a lookup/map/get or if it is called per page or batch from more than one site.
- **Seen:** 1 (pr-review, 2026-10)
