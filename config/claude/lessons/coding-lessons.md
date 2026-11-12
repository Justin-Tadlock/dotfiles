# Coding Lessons Learned

Generic, root-cause lessons from reviews of code Claude wrote. Managed by the
capture-lesson skill.

PUBLIC FILE: it is synced to a public repo. Every entry must pass the
Sanitization Rules in the capture-lesson skill. No project, company, client, product, people,
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

<!-- Promoted (removed from this file): L-007 → CLAUDE.md "Git & Branching"; L-008 → CLAUDE.md "Authorization & Data Access"; L-006 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-009 → CLAUDE.md "Authorization & Data Access"; L-013 → CLAUDE.md "Correctness & Resilience Checklist: Every writer"; L-003 → CLAUDE.md "Correctness & Resilience Checklist: Unknown is not negative"; L-011 → CLAUDE.md "Authorization & Data Access"; L-018 → CLAUDE.md "Correctness & Resilience Checklist: Testability"; L-014 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-027 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-028 → CLAUDE.md "Correctness & Resilience Checklist: Matching pipelines"; L-004 → CLAUDE.md "Correctness & Resilience Checklist: New states reach every consumer"; L-020 → CLAUDE.md "Correctness & Resilience Checklist: Async work outlives its UI"; L-049 → CLAUDE.md "Authorization & Data Access"; L-048 → CLAUDE.md "Correctness & Resilience Checklist: Outcomes from what was confirmed"; L-016 → CLAUDE.md "Correctness & Resilience Checklist: Same equality on both sides"; L-021 → CLAUDE.md "Correctness & Resilience Checklist: Contract changes reach every client"; L-035 → CLAUDE.md "Correctness & Resilience Checklist: Lock order"; L-041 → CLAUDE.md "Correctness & Resilience Checklist: Every variant of an action"; L-046 → CLAUDE.md "Correctness & Resilience Checklist: Test isolation"; L-064 → CLAUDE.md "Correctness & Resilience Checklist: Changes across two systems"; L-068 → CLAUDE.md "Authorization & Data Access"; L-010 → CLAUDE.md "Correctness & Resilience Checklist: Guarantees held by configuration"; L-050 → CLAUDE.md "Correctness & Resilience Checklist: Operator scripts" -->
<!-- Merged: L-058 → L-010 (promoted); L-042 → L-036; L-056 → L-053; L-060 → L-050 (promoted); L-066 → L-023; L-034 → CLAUDE.md "Correctness & Resilience Checklist: Testability" -->
<!-- Lessons start below. Next ID: L-073 -->

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

### L-005: Conditionally unmounting content leaked side effects it registered
- **Area:** React lifecycle, global state
- **Pattern:** Gated a subtree (error/not-found/forbidden state) so it unmounted mid-load. The unmounted subtree had registered a pending event in a global provider (a blocking loading overlay) with no cleanup, so the overlay kept swallowing clicks on the replacement UI.
- **Root cause:** Reviewed only what renders in the new state, not side effects owned by the subtree being removed.
- **Rule:** When adding a gate that unmounts content, list what that subtree registers in shared/global state (loading trackers, subscriptions, timers, listeners) and ensure it is cleared on every terminal path. Test that the cleanup fires exactly once per transition.
- **Check:** For each new conditional render that hides existing children, look for start/register/subscribe calls inside those children without a matching cleanup on that path.
- **Seen:** 1 (pr-review, 2026-10)

### L-015: Parser bound did not match the storage type
- **Area:** validation, types, persistence
- **Pattern:** A parser accepted a value as a number up to one bound but as a string only up to a smaller one, so it rejected its own output after a storage round trip. Separately, an id parser accepted any safe integer while the column was a 32-bit integer, so an out-of-range id passed validation and the database cast failed with a server error.
- **Root cause:** Picked bounds by hand (a string-length guard, the language's safe-integer limit) instead of deriving them from the column type, and didn't test the values at the edge of that type.
- **Rule:** Derive a value's bounds from the storage column's type and enforce them in one shared check used by every input representation and every endpoint that takes the value. Test the largest value the column holds (accepted, then not-found) and one past it (validation error), and that each value the writer emits is accepted again after a storage round trip.
- **Check:** For each id or numeric parser in the diff, find the column type it is compared with or cast to, and confirm the parser's maximum matches it; compare the bounds of each `typeof` branch, and look for a test at the column's maximum and one past it.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

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
- **Check:** For each role list or `Object.values(<RoleEnum>)` in the diff, compare against the stored role set; confirm a test covers every role (including deprecated and newly added ones) for both read and write. Prefer an expectation table typed by the role enum (e.g. `Record<Role, { read; write }>`) so adding a role fails the typecheck until it is placed; per-record checks failing closed do not replace this test.
- **Seen:** 2 (pr-review, 2026-10; self-review, 2026-10)

### L-022: A row cap was applied before the filters that decide eligibility
- **Area:** data access, authorization
- **Pattern:** An access check fetched candidate rows with a limit and then filtered them in application code (deleted, owner, visibility), so rows that would grant access beyond the cap were never considered.
- **Root cause:** Picked the limit for the expected row count, without checking which filters ran before it and which after.
- **Rule:** Push every eligibility filter into the query before the limit. If anything still has to be filtered in code, page until found or exhausted, with a hard cap that fails closed.
- **Check:** For each limited query in the diff, check whether its results are filtered further in code. If so, flag it.
- **Seen:** 1 (pr-review, 2026-10)

### L-023: Classified a failure without knowing which step or outcome it represents
- **Area:** error handling, external APIs
- **Pattern:** A caller mapped "not found" from the first request's error type, but a second step threw a plain `Error`, so users saw an unrelated message. Separately, a create call timed out and the local record was deleted as if nothing had been created, and an eventually consistent search returning nothing right after a write was taken as "none".
- **Root cause:** Mapped failures by their first or most common shape, without asking which step can produce each and which answers the remote system guarantees.
- **Rule:** List every step that can produce a failure kind, have each throw a typed error keeping the status, and classify through one shared helper. Split definite refusals (4xx) from ambiguous outcomes (timeouts, network errors, 5xx); on ambiguity keep a recoverable local state rather than deleting. Cross-check eventually consistent lookups with a consistent one. Test each step's failure and an ambiguous one.
- **Check:** For each status-based branch, trace every awaited step; for each external create/update, ask what happens if a failed call actually succeeded.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-11)

### L-024: Validated a request's host but let the HTTP client follow redirects
- **Area:** security, SSRF, secrets handling
- **Pattern:** A guard checked that a URL pointed at an allowed host before sending a request that carried a secret header and a sensitive body, but the HTTP client followed redirects automatically. A redirect could send the custom header (only standard credential headers are stripped across origins) and, on 307/308, the body to a host the guard never saw.
- **Root cause:** Treated the URL passed to the client as the only destination, without checking the client's redirect behavior.
- **Rule:** When a host/URL allow-list protects a request carrying secrets or privileged payloads, disable or reject redirects (e.g. `redirect: 'error'` / `maxRedirects: 0`), or re-validate every hop manually. Keep the guard and the request in one helper so every call goes through both.
- **Check:** For each host/URL allow-list check in the diff, find the request it guards and confirm redirects are refused or each hop is re-checked.
- **Seen:** 1 (pr-review, 2026-10)

### L-025: Matched an incoming name against a cached copy instead of the live value
- **Area:** data access, caching, identity
- **Pattern:** Resolved incoming names to records by a locally cached copy of an external system's name, while another flow updated the live local record's name first, so lookups missed until the next sync and created duplicates. Later, an email change updated the user record but not the copies of the address stored in notification lists, so notifications kept going to the old address.
- **Root cause:** Listed the writers of the cache, not every writer of the value the cache mirrors.
- **Rule:** When resolving by a mirrored value, list every writer of both the mirror and the live value; match against both (treating conflicts as ambiguous) or update them together.
- **Check:** For each lookup on a synced/cached column in the diff, search for writes to the corresponding live column; flag any path that updates one without the other.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-11)

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

### L-030: Treated knowledge of an object key as a barrier without checking how keys were generated
- **Area:** authorization, storage
- **Pattern:** An access rule granted a download when any row the caller could see referenced the object's URL. The caller could write that column on their own row, so the rule reduced to "knows the key", and older keys were the client-supplied file name, so they were guessable. Later, a scope rule required every membership of the target to be one of the caller's, to defeat a caller adding the target to its own group; a target with no other memberships still passed after the caller added the one forged row.
- **Root cause:** Checked forgeability for one table the rule read but not the others, and assumed keys were unguessable from the current generator without checking every earlier generator. Treated a stricter condition over forgeable rows as fixing forgeability, without testing the case where the forged row is the only row.
- **Rule:** For each row an access rule relies on, confirm the caller can't write the referencing column on any row they can see. Bind the key to the specific record it belongs to and check that record only. Never treat a key as secret unless every generator, current and past, produced unguessable keys. A rule over rows the caller can create ("all of the target's links are mine") is still forgeable when the caller can create the only link; remove the write permission instead and test the zero-row case.
- **Check:** For each "a visible row references this URL/key" grant in the diff, list which roles can write that column on rows they can see, and how every historical key format was produced.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-11)

### L-031: Designed a data flow between "related" records without checking the uniqueness that defines them
- **Area:** data modeling, persistence
- **Pattern:** Planned to copy data from a "previous" record matched by a natural key to the current one, but a unique constraint on that key meant the match was always the same row, so the copy was a no-op and the design added dead code.
- **Root cause:** Reasoned from field names and query shape without reading the table's unique constraints.
- **Rule:** Before designing a lookup or copy between records matched by a natural key, check the unique constraints and indexes on that key; if it is unique, the "related" record is the record itself.
- **Check:** For each query in the diff that finds "other" rows by a set of columns, confirm whether those columns are unique together, and that a test seeds two rows that share them.
- **Seen:** 1 (self-review, 2026-10)

### L-032: Insert-if-absent treated a soft-deleted row as "already present"
- **Area:** persistence, data access
- **Pattern:** Used an insert with a conflict clause that does nothing on a duplicate key, but the unique key also covered soft-deleted rows, so a deleted row with the same key silently blocked the insert and the operation reported success with the data still hidden.
- **Root cause:** Assumed a key conflict meant a live duplicate, without checking whether the constraint covers tombstoned rows.
- **Rule:** For any conflict-tolerant insert on a table with soft deletes, check whether the unique key includes deleted rows; if it does, restore the conflicting deleted row (update only where it is deleted) or use a partial unique index on live rows. Test a conflict with a live row and with a deleted row.
- **Check:** For each `ON CONFLICT ... DO NOTHING` (or equivalent upsert/ignore) in the diff, find the conflict target's constraint and whether the table has a soft-delete column; if it does, confirm the deleted-row case is handled and tested.
- **Seen:** 1 (pr-review, 2026-10)

### L-033: A handler's narrower role rule lived only in the route wiring
- **Area:** authorization
- **Pattern:** An endpoint allowed fewer roles than the shared access helper it called (the helper also let a broader admin role write). Only the route's role guard enforced the narrower set, so the handler itself would have let that broader role act if it were mounted elsewhere or the guard changed.
- **Root cause:** Treated the route guard as the authoritative role check, while the per-record helper decided scope but not that narrower role set.
- **Rule:** When an operation's allowed roles are narrower than what the access helper it uses permits, check the role inside the handler as well, before any data access, and test the handler directly with a role the helper would allow.
- **Check:** For each handler in the diff, compare the route's allowed roles with the roles its access helper accepts for the same access level; if the route is narrower, confirm the handler re-checks the role and a direct test covers it.
- **Seen:** 1 (pr-review, 2026-10)

### L-036: Relied on transaction guarantees without checking them
- **Area:** database, concurrency
- **Pattern:** A service's `transaction()` sent BEGIN/COMMIT as ordinary pooled queries, so statements ran on different connections and locks didn't hold. Separately, a handler authorized rows and then re-selected them for the write; under READ COMMITTED a concurrent change between the reads made the write act on fewer rows than were checked.
- **Root cause:** Trusted a method name and assumed one transaction means one connection and one snapshot.
- **Rule:** Before relying on a transaction for locks, atomicity or consistent reads, confirm it checks out one connection for every statement and the commit. Write from the rows you authorized (pass their values) or lock them in the first read, checking the locks can't deadlock with the write's own. Test with a change committed on another connection between check and write.
- **Check:** For each transaction, find where its connection comes from; for each `INSERT ... SELECT`/`UPDATE ... FROM` over rows checked earlier in the same transaction, confirm they're locked or passed in.
- **Seen:** 2 (pr-review, 2026-10; user-feedback, 2026-10)

### L-037: NULL comparisons silently passed or dropped rows
- **Area:** authorization, SQL
- **Pattern:** An access check required `bool_and(a.x = b.x)` across all requested rows. A NULL column made the comparison NULL, which `bool_and` skips, so a row with a missing link passed whenever another row was consistent. Later, a filter rebuilding a JSON array kept elements `WHERE value <> x`; JSON null elements compared as NULL and were dropped, and the rebuilt array had no defined order.
- **Root cause:** Treated the comparison as true or false, without considering that SQL aggregates ignore NULL inputs.
- **Rule:** In aggregated access checks, make every condition count NULL as a denial (e.g. `COALESCE(cond, false)`). Test a batch that mixes a valid row with one whose link is NULL. Use `IS DISTINCT FROM` / `IS NOT DISTINCT FROM` when a filter must keep NULL-valued items, and `WITH ORDINALITY ... ORDER BY` when rebuilding arrays.
- **Check:** For each `bool_and` / `every` / `count(col)` / `min` in an authorization query, ask what a NULL input does, and confirm a test covers it. For each `<>`/`=` filter over values that can be NULL (including JSON elements extracted with `#>>`), ask whether NULL items should be kept.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-11)

### L-038: After authorizing a record, used its references without checking they belong to it
- **Area:** authorization, data access
- **Pattern:** An export authorized a set of records, then joined a related row through a pointer column and returned its content. Clients had once been able to write that pointer, so it could reference another tenant's row. Separately, a bulk write scoped records through one relationship while the access check required two relationships to agree, so it acted on records the check would deny.
- **Root cause:** Treated authorizing the root record as authorizing everything reachable from it, and wrote the bulk query's scope by hand instead of reusing the check's conditions.
- **Rule:** When returning or changing data reached through a reference, also require that the referenced row belongs to the authorized record, for example that its back-reference matches. Every query acting on an authorized set must apply the same consistency conditions as the access check.
- **Check:** For each join on a pointer column in the diff that returns data, confirm it also matches the target row's back-reference or owner. For each bulk write scoped by a relationship, compare its conditions with the access helper's.
- **Seen:** 1 (pr-review, 2026-10)

### L-039: Treated a status column as the whole lifecycle state
- **Area:** data modeling, validation
- **Pattern:** A guard treated any child row with an "in progress" status as active and blocked new ones. A background job ended rows by setting a separate expiry flag, leaving the status unchanged, and reopened the parent, so expired rows still blocked new submissions.
- **Root cause:** Inferred what "active" means from the status values, without reading every writer that ends a row's lifecycle.
- **Rule:** Before writing an "active/open/live" predicate, list every writer that moves rows out of that state (jobs, admin actions, soft deletes, expiry flags) and include each one's marker. Test a row ended by each writer.
- **Check:** For each status-based filter in the diff, including subqueries that pick "the current" child row (`... LIMIT 1`), look for other columns written alongside status changes (expired/deleted/closed flags or timestamps), and confirm the filter accounts for them and the pick has a deterministic order.
- **Seen:** 2 (pr-review, 2026-10; self-review, 2026-10)

### L-040: Bulk update set a single-valued parent field from several children in one batch
- **Area:** persistence, data integrity
- **Pattern:** A bulk action marked a batch of child rows accepted and set each parent's "accepted child" pointer from them with an `UPDATE ... FROM (VALUES ...)`. When two children of one parent were in the batch, both were marked accepted and the database picked an arbitrary row for the pointer.
- **Root cause:** Assumed each parent had at most one qualifying child, without checking which writers (resets, reopen jobs, resubmissions) can leave several.
- **Rule:** When a bulk write derives a single-valued parent field from child rows, choose one child per parent deterministically (or reject the batch) before writing, and list every writer that can create several qualifying children. Test a batch with two children of one parent, in both orders.
- **Check:** For each `UPDATE ... FROM` / join-driven update in the diff, ask whether the source can contain several rows for one target row; if so, confirm the source is deduplicated with a stated rule and a test covers it.
- **Seen:** 1 (self-review, 2026-10)

### L-043: Put a test file inside a directory the framework serves as routes
- **Area:** testing, deployment
- **Pattern:** Added tests next to API route handlers in a file-system-routed framework. The build config didn't exclude test files, so each would have been built and served as an endpoint.
- **Root cause:** Followed the existing "test next to source" layout without checking how the framework treats every file in that directory.
- **Rule:** In file-system-routed frameworks, keep tests outside the routes directory unless the config limits route files to specific extensions. Import the handler from the test.
- **Check:** For each new test file in the diff, check whether it sits under a routes directory, and whether the router config excludes `*.test.*`.
- **Seen:** 1 (self-review, 2026-10)

### L-044: An effect that starts a request depended on a callback recreated every render
- **Area:** React hooks, async
- **Pattern:** A child started an upload in an effect when its status became "start", with the parent's upload callback in the dependency array. The parent recreated that callback on every render, so any parent re-render during the upload started it again and saved a duplicate record. The first fix kept the guard in the child, which resets when list keys shift (index keys, prepended items) and remount it, so dropping another file still restarted the upload.
- **Root cause:** Rewrote the callback's body without checking how its consumer invokes it, and treated the effect's status condition as a once-only trigger.
- **Rule:** An effect that starts a non-idempotent request must fire once per input: record the input it started for in the component that owns the list (keyed by the input, so it survives child remounts), or make every dependency stable. Test a re-render and a remount while the request is pending.
- **Check:** For each effect in the diff that calls a request or mutation, list its dependencies and confirm each is stable (memoized or from state) or that a ref guards the start; look for a test that re-renders mid-request. If the guard lives in a list item, check whether its key can change while the request runs.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-045: A resume or "finish" action skipped the step that established its precondition
- **Area:** state transitions, data integrity
- **Pattern:** A multi-step status change could resume at a failed step or "finish" without its first step (setting the status). The later steps (closing items, blocking accounts) trusted the page's copy of the status, so a stale page could run them against a record whose status had since been changed back.
- **Root cause:** Treated the first step's success as permanent for the rest of the run, without considering that resuming skips it and that the record can change between runs.
- **Rule:** When steps depend on a state an earlier step set, re-read the stored state before each irreversible step (or atomically on the server) and stop if it no longer holds; treat an unreadable state as a stop. Test a resume after the state was changed elsewhere.
- **Check:** For each resumable or partial-rerun flow in the diff, find what the skipped steps established, and confirm the remaining steps verify it from storage rather than from client state.
- **Seen:** 1 (pr-review, 2026-10)

### L-047: Mapped API errors on the client without checking what the proxy in between forwards
- **Area:** error handling, API contracts, testing
- **Pattern:** The client mapped the API's 400 messages, but a proxy turned 400s into 500s with a generic body for most roles, so the mapping only worked for one role. Separately, the API refused an "all items already handled" batch with a 400 instead of returning a zero count, so a skip was reported as a failure. Later, new endpoints used PATCH/PUT while the proxy only forwarded GET and POST, and passed bodies only for 400, so the new conflict and retry messages could never reach the user.
- **Root cause:** Tests mocked the client helper below the proxy, and the design followed the API's documented counts without reading its edge-case branches.
- **Rule:** Before mapping error statuses or messages, trace them through every hop to the browser for each role, and read the API handler's branches for empty or all-skipped input. Test at least one case through the proxy.
- **Check:** For each status or message branch in client error handling, find the proxy code for that status and role, and the API branch that produces it. List the HTTP methods and statuses the proxy forwards before choosing routes and error codes.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-11)

### L-051: Checked an allowlist object with `in`
- **Area:** validation, JavaScript
- **Pattern:** Checked an input string against an object-literal allowlist with `in`, which also matches inherited properties (`constructor`, `__proto__`). Crafted input passed the check, and the lookup returned a function instead of a value. Later, a test fixture looked up a per-role table with a bare index, so an unplaced role id such as `constructor` got an inherited function as its value and a denial test failed for the wrong reason.
- **Root cause:** Treated the object literal as a set without considering its prototype chain.
- **Rule:** Check untrusted keys against a `Set`, a `Map`, or an own-property test (`Object.hasOwn` / `hasOwnProperty.call`), never `in` or a bare index. Test with `constructor` and `__proto__`. This applies to test fixtures and expectation tables too.
- **Check:** For each `x in OBJ` or `OBJ[input]` in the diff where the input is untrusted, confirm it uses an own-property or Map/Set lookup.
- **Seen:** 2 (pr-review, 2026-11; self-review, 2026-11)

### L-052: Relied on a shared helper to store a field without checking that it does
- **Area:** audit/logging, API contracts
- **Pattern:** New code passed a field to a shared logging helper whose parameter type declared it, but the helper copied only a few named fields into the stored record and dropped the rest. The new feature's records were missing the data it was written to capture. The gap was noticed in review but filed as an existing bug because the helper was untouched.
- **Root cause:** Took the helper's parameter type as proof the field was stored, and judged the gap by who wrote the helper rather than by whether the new feature depended on it.
- **Rule:** When new code depends on a helper persisting or sending a value, read the helper down to what it actually writes, and add a test on the payload that reaches the storage call (not on the arguments passed to the helper). A defect in untouched code becomes part of the change once the change relies on it; fix it there or narrow the change.
- **Check:** For each field the diff passes to a logging, persistence or request helper, confirm the helper's body forwards it to the final write, and that some test asserts it in that write's payload. Flag any helper whose parameter type has fields its body never reads.
- **Seen:** 1 (pr-review, 2026-11)

### L-053: Result types drifted from what the code actually receives
- **Area:** types, API contracts
- **Pattern:** An unvalidated response generic was replaced with `Record<string, unknown>`, erasing the only in-code description of the response so property typos compiled. Separately, a query stopped selecting a field but its result type (a broad entity type intersected with extras) still declared it, so readers compiled and got `undefined`.
- **Root cause:** Treated types as either a claim to remove or something that tracks the query by itself, instead of the contract to keep in step with what's fetched.
- **Rule:** For unvalidated data, keep the field names and drop only the value types (`{ [K in keyof T]?: unknown }`) derived from the validated type. When a selection changes, rebuild the result type from it (`Omit<Entity, 'field'> & {...}`) and retype callbacks that use the broad entity type.
- **Check:** For each `unknown`/`any`/`Record<string, unknown>` response type, confirm the fields are still named; for each field removed from a selection, confirm the result type no longer declares it.
- **Seen:** 2 (user-feedback, 2026-11; pr-review, 2026-11)

### L-054: Cherry-picked a string key without checking what it matches on the target branch
- **Area:** git, configuration, cross-branch ports
- **Pattern:** Ported a config entry whose keys are matched by string against definitions elsewhere (column ids, field paths). The cherry-pick applied cleanly, but the target branch still used the older definitions, so nothing matched and the feature silently disappeared for every user.
- **Root cause:** Treated a clean apply as proof the change fit the target, without looking at the code the values are matched against, which was outside the diff.
- **Rule:** When porting a value that is looked up by string (ids, keys, paths, event names), find what it is compared with on the target branch and confirm it still matches; if the two sides drifted, keep the target's value. Add a test that runs the real matching rule over the real definitions so a mismatch fails.
- **Check:** For each cherry-picked change to a config map, registry or key-to-handler table, search the target branch for the consumer that matches those keys and compare both sides; look for a test that feeds the actual definitions through the lookup.
- **Seen:** 1 (self-review, 2026-11)

### L-057: Appended default sort keys without checking overlap with the user's sort
- **Area:** data access, pagination
- **Pattern:** Added fixed tiebreakers (name, then id) after the user's sort to make pagination stable. When the user sorted by one of the tiebreaker fields, the order list named that field twice with opposite directions, relying on unverified server behavior for duplicates.
- **Root cause:** Built the list as "user input + defaults" without considering inputs that overlap the defaults.
- **Rule:** When appending default keys (sort tiebreakers, default filters, default fields) to user-supplied ones, skip defaults that name a field the user already set, and test with a user value equal to each default.
- **Check:** For each `[userValue, ...defaults]` composition in the diff, ask what happens when the user's value uses a default's key; confirm a test covers it.
- **Seen:** 1 (pr-review, 2026-11)

### L-059: Used an object's last-modified time as the time its content was written
- **Area:** storage, data migration
- **Pattern:** A migration decided which objects an old code version wrote by comparing their last-modified time with the date that version was replaced. An earlier bulk job had changed access settings on most objects, which reset that timestamp, so every object looked new and the migration refused all of them.
- **Root cause:** Treated a storage-set timestamp as evidence of when the content was written, without listing past operations that update it (ACL changes, metadata rewrites, in-place copies).
- **Rule:** Before deciding by an object's last-modified time, search history for bulk jobs that touched the objects, and check real objects' dates for clusters. Treat dates inside such a job's window as unknown, not as dates.
- **Check:** For each comparison of an object's last-modified time in the diff, look for a dry run showing the real date distribution and for bulk object-rewrite scripts in history.
- **Seen:** 1 (self-review, 2026-11)

### L-061: Logged caller-chosen object keys as if they were safe metadata
- **Area:** logging, validation
- **Pattern:** To avoid logging sensitive values from a request body, logged the body's key names instead. The keys are caller input too: a request could put arbitrary text (including someone else's personal data) or megabytes of characters into a key, and it went straight into the logs. Capping the number of keys didn't bound their length.
- **Root cause:** Treated "names, not values" as inherently safe without asking who controls the names.
- **Rule:** Log only allow-listed key names that are present, plus a count of the rest. Never log raw keys, header names, or other caller-chosen identifiers without an allow-list or a length bound.
- **Check:** For each log call in the diff that includes `Object.keys(...)`, header names, or other request-derived identifiers, confirm the values are filtered through an allow-list; look for a test with a very long key and a key containing personal data.
- **Seen:** 1 (pr-review, 2026-11)

### L-062: Restored an environment variable by assigning a possibly-undefined value
- **Area:** testing, Node.js
- **Pattern:** A test saved an environment variable, overwrote it, and restored it in teardown with `process.env.X = saved`. When the variable was originally unset, the assignment stored the string `"undefined"`, which leaked into later test files because the runner shared one process without isolation.
- **Root cause:** Assumed assigning `undefined` to `process.env` removes the key; Node coerces every assigned value to a string.
- **Rule:** When restoring an environment variable, `delete process.env.X` if the saved value is `undefined`, otherwise assign it; or use the test runner's env stubbing with automatic restore (e.g. `vi.stubEnv` + `vi.unstubAllEnvs`).
- **Check:** For each `process.env.X = <saved>` in test teardown in the diff, confirm the undefined case deletes the key or that the runner's env stub/restore is used.
- **Seen:** 1 (pr-review, 2026-11)

### L-063: Passed already-formatted SQL to a helper that formats its input again
- **Area:** SQL, data access, injection
- **Pattern:** Built a dynamic query by formatting values into its text, then passed that string to a database helper that runs the same printf-style formatter on every query it receives. A placeholder sequence inside a stored value (for example `%L` or `%s` in free text) would have been expanded again on the second pass.
- **Root cause:** Assumed the helper formats only when it is given arguments, without reading it.
- **Rule:** Before passing SQL to a query helper, read whether it formats its input. Build dynamic templates only from fixed identifiers (quoted once) and placeholders, and pass every value as an argument in a single formatting pass. Test with a value that contains the formatter's placeholder syntax.
- **Check:** For each query call in the diff, confirm the template contains no substituted values (no nested format call or interpolated value in the string), and look for a test value such as `100%L %s`.
- **Seen:** 1 (self-review, 2026-11)

### L-065: Added a writer that stores an unverified value in a field consumers treat as verified
- **Area:** authorization, identity, data integrity
- **Pattern:** A field (an account's email) was trusted downstream as belonging to the user, because the only self-service path verified it first. A new administrative path set it directly, so a downstream token signer started asserting an address nobody had proven to own. Later, the new verification flag defaulted to true, so rows inserted by older writers were trusted, and the check accepted a verified flag asserted by an external identity provider the customer controls.
- **Root cause:** Checked who may call the new writer, not what every consumer assumes about values in that field.
- **Rule:** When adding a writer to a field, list its consumers and the guarantees they rely on (verified, normalized, owned). If the new writer can't provide one, store that state explicitly (e.g. a verified flag) and make each consumer check it, failing closed. Default a trust flag to the untrusted value for new rows (backfill existing rows explicitly), and accept proof only from sources the system itself controls.
- **Check:** For each new write to an identity or contact field in the diff, find every reader of that field that signs, sends to, or authorizes with it, and confirm the new value meets the reader's assumption or is marked so the reader refuses it.
- **Seen:** 2 (pr-review, 2026-11; pr-review, 2026-11)

### L-067: An endpoint revealed existence before its rate limit applied
- **Area:** security, enumeration
- **Pattern:** A self-service endpoint answered "address in use" immediately and checked its per-user throttle only on the success path, so any signed-in user could test unlimited addresses for existence. Later, the throttle record was deleted on refusal paths, and one class of caller got a refusal only for unused identifiers, so it could still probe without limit.
- **Root cause:** Placed the throttle where the expensive side effect (sending email) happens, not before the first branch that differs by existence.
- **Rule:** Apply rate limits before any lookup whose outcome changes the response, and answer the same for existing and non-existing targets where existence is sensitive (move the difference into an out-of-band notice). Keep the throttle record on every path (invalidate rather than delete it), and order checks so no branch differs by existence for any caller.
- **Check:** For each endpoint in the diff that looks up a user-supplied identifier, compare the responses for "exists" and "doesn't exist" and confirm the throttle runs before that lookup.
- **Seen:** 2 (pr-review, 2026-11; pr-review, 2026-11)

### L-069: Edited a migration that may already have been applied instead of adding a new one
- **Area:** database, migrations, deployment
- **Pattern:** Added new columns and a table to a migration file that was already committed (and run against shared or developer databases). Migration tools track applied versions, so any database that had run that version would silently skip the additions and the code would fail at runtime.
- **Root cause:** Treated "not yet deployed to production" as "not yet applied anywhere".
- **Rule:** Once a migration is committed, put further schema changes in a new migration, unless you can confirm no database has applied it.
- **Check:** For each changed (not added) migration file in the diff, check whether the earlier version was committed; if so, flag it.
- **Seen:** 1 (pr-review, 2026-11)

### L-070: Stated a timing bound in a comment instead of deriving it from the limits
- **Area:** concurrency, external APIs
- **Pattern:** A lease that had to outlast the external calls made between renewals was set to a fixed duration, with a comment claiming it covered the worst case. Computed from the client's per-attempt timeout, retry count and maximum retry wait, the slowest sequence of calls between two renewals took longer than the lease, and some paths never renewed at all.
- **Root cause:** Wrote the bound from an estimate of typical call counts, without multiplying out the configured limits or checking where renewals actually ran.
- **Rule:** When a duration must exceed the worst case of bounded operations (leases, locks, job timeouts), compute it in code from the same constants that bound those operations, renew before every external call rather than per batch, and add a test asserting the inequality so raising a limit fails it.
- **Check:** For each lease/lock TTL or timeout in the diff, find the external calls made between renewals, multiply out attempts × timeout + retries × max wait, and compare; flag literal TTLs with comments claiming they cover the worst case.
- **Seen:** 1 (pr-review, 2026-11)

### L-071: Replaced a linear built-in with a backtracking regex on untrusted input
- **Area:** performance, security, regex (ReDoS)
- **Pattern:** To make a trim strip exactly the characters another layer strips, replaced the language's built-in trim with an alternation regex (`^[set]+|[set]+$`). The unanchored second branch is retried at every position of a long whitespace run and backtracks each time, so cost grew quadratically; the helper ran on request bodies, so one large request could block the event loop for minutes.
- **Root cause:** Checked the rewrite only for matching output (same character set as the other layer), not for its cost on hostile input, and didn't check whether any caller passed request data.
- **Rule:** When replacing a built-in string operation, keep it linear: use an explicit scan, or a fully anchored pattern whose quantified parts can't match the same text in more than one way. Before running any regex on caller-controlled input, bound the input length or confirm it has no unanchored `X+$`, nested quantifiers, or overlapping quantified alternatives. Test a very long adversarial input with a time bound.
- **Check:** For each new regex in the diff, trace whether request-derived strings reach it; flag unanchored `+$`/`*$`, nested quantifiers and overlapping quantified alternatives; look for a long-input timing test.
- **Seen:** 1 (pr-review, 2026-11)

### L-072: Let either of two unsynchronized links grant access
- **Area:** authorization, data modeling
- **Pattern:** A scope rule put a target in scope when a direct owner column on the target named one of the caller's accounts, and otherwise only when every group membership of the target belonged to the caller's accounts. Nothing kept the direct column in sync with the memberships, so a target whose column named the caller but whose groups all belonged to another account was in scope. The "every membership" rule never ran for them.
- **Root cause:** Assumed two references that should agree actually do, without checking which writers set each one, and combined them with OR, so the weaker link short-circuited the stricter check.
- **Rule:** When two independently written links relate the same records, either pick one as the source of truth for the decision or require both to agree; never let either one alone grant access. Before relying on a denormalized column, list its writers and confirm something keeps it consistent. Test a target whose links disagree, in each direction, and one with only the weaker link.
- **Check:** For each scope or access predicate in the diff, look for an early `return true` on one relationship ahead of a stricter check on another. Confirm what keeps the two consistent, and look for tests where they disagree.
- **Seen:** 1 (pr-review, 2026-11)
