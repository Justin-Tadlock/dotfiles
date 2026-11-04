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

<!-- Promoted (removed from this file): L-007 → CLAUDE.md "Git & Branching"; L-008 → CLAUDE.md "Authorization & Data Access"; L-006 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-009 → CLAUDE.md "Authorization & Data Access"; L-013 → CLAUDE.md "Correctness & Resilience Checklist: Every writer"; L-003 → CLAUDE.md "Correctness & Resilience Checklist: Unknown is not negative"; L-011 → CLAUDE.md "Authorization & Data Access"; L-018 → CLAUDE.md "Correctness & Resilience Checklist: Testability"; L-014 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-027 → CLAUDE.md "Correctness & Resilience Checklist: Defensive boundaries"; L-028 → CLAUDE.md "Correctness & Resilience Checklist: Matching pipelines"; L-004 → CLAUDE.md "Correctness & Resilience Checklist: New states reach every consumer"; L-020 → CLAUDE.md "Correctness & Resilience Checklist: Async work outlives its UI"; L-049 → CLAUDE.md "Authorization & Data Access"; L-048 → CLAUDE.md "Correctness & Resilience Checklist: Outcomes from what was confirmed" -->
<!-- Lessons start below. Next ID: L-058 -->

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

### L-010: Structural policy test matched a required clause at any depth
- **Area:** testing, authorization
- **Pattern:** A test asserting "every permission rule requires clause X" searched the whole expression tree for X, so X under an unrelated relationship, under a negation/disjunction, or reached through a one-to-many relationship satisfied it without enforcing the intended scope. Through a to-many hop, X means "some related row qualifies", not "this row qualifies".
- **Root cause:** Wrote the matcher for the shapes that existed, not for the shapes an incorrect rule could take.
- **Rule:** Policy-lint tests must match the required clause only at the specific path that gives the scoping meaning: reject it under `not`/`or`/unrelated relationships, follow only single-row (to-one) relationships to reach it, and treat unknown keys as failing. Include negative fixtures for each bypass shape.
- **Check:** For each recursive matcher in a policy test, try writing a rule that passes the matcher but doesn't enforce the policy (including one that reaches the clause through a to-many relationship); if one exists, flag it.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-015: Parser bound did not match the storage type
- **Area:** validation, types, persistence
- **Pattern:** A parser accepted a value as a number up to one bound but as a string only up to a smaller one, so it rejected its own output after a storage round trip. Separately, an id parser accepted any safe integer while the column was a 32-bit integer, so an out-of-range id passed validation and the database cast failed with a server error.
- **Root cause:** Picked bounds by hand (a string-length guard, the language's safe-integer limit) instead of deriving them from the column type, and didn't test the values at the edge of that type.
- **Rule:** Derive a value's bounds from the storage column's type and enforce them in one shared check used by every input representation and every endpoint that takes the value. Test the largest value the column holds (accepted, then not-found) and one past it (validation error), and that each value the writer emits is accepted again after a storage round trip.
- **Check:** For each id or numeric parser in the diff, find the column type it is compared with or cast to, and confirm the parser's maximum matches it; compare the bounds of each `typeof` branch, and look for a test at the column's maximum and one past it.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-016: Compared counts from two layers that use different equality rules
- **Area:** authorization, data access, validation
- **Pattern:** Deduplicated input ids in application code with exact string equality, then required the database to return one row per id. The database compared the column type with its own equality rule (case-insensitive for that type), so two spellings of one id produced one row, the counts disagreed, and a valid request was denied.
- **Root cause:** Assumed the application's notion of "same value" matched the database's, without checking how the column type compares values.
- **Rule:** Before comparing an input count with a result count (or matching input values against returned values), put the input in the same canonical form the storage layer compares by (case, whitespace, numeric vs. string), then deduplicate. Test with two spellings of the same value. A stored reference may also spell the same value differently depending on its writer (percent-encoding, hex case, `+` for a space); list how each writer encodes it, and when a match blocks an action, match every spelling.
- **Check:** For each `new Set(...)` or dedup in the diff whose size is compared with a query's row count, confirm the elements are normalized to the column type's equality first, and that a test sends differently cased or formatted duplicates. For each match on a stored URL or path, list how its writers encode it and confirm a test covers each spelling.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-11)

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

### L-021: Changed a server boundary's contract without auditing clients that bypass the shared helper
- **Area:** validation, API contracts, error handling, deployment
- **Pattern:** Added stricter input bounds and value normalization to an endpoint and improved error formatting in the shared client helper, but another client called the endpoint directly: it pre-transformed a field past the new bound, persisted the raw (un-normalized) value that a stricter downstream reader rejected, and kept showing the transport error instead of the server's message. Separately, a new per-request cap was paired with a client change to batch requests, but the old client, still live until the client deploy, sent everything at once and swallowed the error, so the action looked successful while it did nothing.
- **Root cause:** Audited callers of the helper, not every caller of the endpoint; and checked what each client will send after its update, not what the current client does with the new rejection during the rollout.
- **Rule:** When changing an endpoint's validation, normalization or error shape, search for every request to that endpoint (not just helper usages). For each, check the transformations applied before sending against the new bounds, persist the server-normalized value rather than the raw input, and route errors through the shared formatter. When the server deploys before its clients, state what each current client does when the new check rejects it (especially callers that ignore or only log errors) and put that window in the deploy plan.
- **Check:** For each tightened bound or normalization in the diff, search for the endpoint path across the client code; for each hit, compare what it sends and stores with the new contract, and trace how the deployed version handles a rejection (awaited? surfaced to the user?).
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

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

### L-030: Treated knowledge of an object key as a barrier without checking how keys were generated
- **Area:** authorization, storage
- **Pattern:** An access rule granted a download when any row the caller could see referenced the object's URL. The caller could write that column on their own row, so the rule reduced to "knows the key", and older keys were the client-supplied file name, so they were guessable.
- **Root cause:** Checked forgeability for one table the rule read but not the others, and assumed keys were unguessable from the current generator without checking every earlier generator.
- **Rule:** For each row an access rule relies on, confirm the caller can't write the referencing column on any row they can see. Bind the key to the specific record it belongs to and check that record only. Never treat a key as secret unless every generator, current and past, produced unguessable keys.
- **Check:** For each "a visible row references this URL/key" grant in the diff, list which roles can write that column on rows they can see, and how every historical key format was produced.
- **Seen:** 1 (pr-review, 2026-10)

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

### L-034: Denial test passed through a later "not found" instead of the rule it named
- **Area:** testing, authorization
- **Pattern:** A unit test asserted a denied caller got 404. With the rule removed, the handler went on to query the test database, found no such record, and also returned 404, so the test still passed.
- **Root cause:** Assumed no data layer was reachable in unit tests, so any 404 had to come from the rule, without checking how the test environment routes default connections.
- **Rule:** When a denial shares its response with a later "not found" path, assert that the work after the rule never ran (inject the transaction runner or data layer and assert it was not called), and confirm the test fails with the rule disabled.
- **Check:** For each test in the diff that expects a denial status, ask whether a later step could return the same status; if so, confirm it asserts a boundary (no query, no transaction, no write) as well as the status.
- **Seen:** 1 (self-review, 2026-10)

### L-035: Set a lock order without auditing every writer's locks
- **Area:** concurrency, database
- **Pattern:** Reordered row locks in request handlers to match one documented order, but a background job took explicit table locks on the same tables in the opposite order, so a request holding a row lock and the job could deadlock. Later, a bulk update written next to them took row locks implicitly, in whatever order the query plan visited the rows.
- **Root cause:** Listed the writers changed in the diff, not every writer of those tables, and did not count table-level locks in scheduled jobs as part of the order.
- **Rule:** Before stating or changing a lock order, find every writer of the tables involved (request handlers, jobs, imports, maintenance scripts), including explicit table locks, and make them all follow the same order. Test each pairing that can overlap with a deterministic lock-wait test (hold one lock, wait until the other session blocks, then take the next lock). A multi-row UPDATE/DELETE on rows that other writers lock in a set order must first select the ids with `ORDER BY id FOR UPDATE`, then update by id.
- **Check:** For each new `FOR UPDATE`, `LOCK TABLE` or multi-table write sequence in the diff, search for other code writing those tables and compare the order in which each acquires them, and each multi-row UPDATE/DELETE on those tables.
- **Seen:** 2 (pr-review, 2026-10; pr-review, 2026-10)

### L-036: Relied on a service's transaction method without checking that it pins one connection
- **Area:** database, concurrency
- **Pattern:** Added a row lock inside an existing `service.transaction(...)` call. The service wrapped a connection pool, and its transaction method sent BEGIN and COMMIT as ordinary queries, so each statement could run on a different pooled connection. The lock didn't hold, statements ran outside the transaction, and a connection could be left with a transaction still open.
- **Root cause:** Trusted the method name without reading whether it checks out a dedicated client.
- **Rule:** Before relying on a transaction for locks, atomicity or rollback, confirm the helper checks out one connection and runs every statement and the commit on it. With a pool, use the helper that acquires a client and releases it in `finally`.
- **Check:** For each transaction in the diff, find where its connection comes from. Flag it if the object it runs on may be a pool rather than a checked-out client.
- **Seen:** 1 (pr-review, 2026-10)

### L-037: Aggregated access check let NULL comparisons pass
- **Area:** authorization, SQL
- **Pattern:** An access check required `bool_and(a.x = b.x)` across all requested rows. A NULL column made the comparison NULL, which `bool_and` skips, so a row with a missing link passed whenever another row was consistent.
- **Root cause:** Treated the comparison as true or false, without considering that SQL aggregates ignore NULL inputs.
- **Rule:** In aggregated access checks, make every condition count NULL as a denial (e.g. `COALESCE(cond, false)`). Test a batch that mixes a valid row with one whose link is NULL.
- **Check:** For each `bool_and` / `every` / `count(col)` / `min` in an authorization query, ask what a NULL input does, and confirm a test covers it.
- **Seen:** 1 (pr-review, 2026-10)

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

### L-041: One variant of an action skipped a precondition or side effect another variant performs
- **Area:** validation, state transitions, data integrity
- **Pattern:** The single-item path of an action refused items whose parent was already finalized, but the bulk path only filtered on the item's own status, so a bulk request could overwrite a parent's finalized state. Separately, a bulk "close" that replaced a client mutation copied that mutation's behavior (change one status column), while the server's own single-item reject also updated the other status columns and cleared a related row's pointer to the item; the leftover pointer blocked new submissions later.
- **Root cause:** Wrote the new variant from the item's own fields or from the code it replaced, without listing every check and every related write the existing variant of the same transition performs.
- **Rule:** When an action has several forms (single and bulk, user-facing and administrative, an API path replacing a client write), derive them from one function that applies the same eligibility checks and the same related writes (status columns, pointers, counters), or list both and carry each one over. Test each refusal and each related write through every form.
- **Check:** For each new or changed variant of a state transition in the diff, find the other code paths that perform the same transition; list their refusal conditions and the columns and related rows they write, and confirm the variant applies each one, with a test per item.
- **Seen:** 2 (self-review, 2026-10; user-feedback, 2026-10)

### L-042: Read the same rows twice in a transaction assuming both reads see the same data
- **Area:** concurrency, database
- **Pattern:** A handler loaded and authorized a set of rows, then wrote using a second query that read those rows again with the same filters. Under READ COMMITTED each statement sees newly committed data, so a concurrent change between the two reads made the write act on fewer rows than were checked, and the request still reported success.
- **Root cause:** Assumed one transaction gives one snapshot, without checking the isolation level or whether the rows were locked.
- **Rule:** Write from the rows you authorized (pass their values into the write) rather than re-selecting them, or lock them in the first read. Before choosing locks, check that they can't deadlock with the write's own conflict or row locks in overlapping requests. Test with a change committed on another connection between the check and the write.
- **Check:** For each write in the diff that uses `INSERT ... SELECT` / `UPDATE ... FROM` over rows an earlier statement in the same transaction read and checked, confirm the rows are locked or the write uses the checked values, and that a test commits a change between the two.
- **Seen:** 1 (user-feedback, 2026-10)

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

### L-046: Module mocks leaked into other test files under a shared module registry
- **Area:** testing
- **Pattern:** The unit test config ran files without isolation. A new test mocked a shared server module, and a later file that mocked the same module got the first file's mock, so its tests failed depending on file order. Resetting the module cache after the file was not enough, because the mock registration stayed.
- **Root cause:** Assumed each test file gets fresh modules, and then assumed clearing the module cache also removes registered mocks; verified only with the default file order.
- **Rule:** Before mocking a shared module, check the runner's isolation setting. Without isolation, unregister each mock after the file (e.g. `vi.doUnmock(path)` for every mocked path, then `vi.resetModules()`), and run the suite with shuffled file order (e.g. `--sequence.shuffle.files` with a few seeds) before calling it done.
- **Check:** For each new `vi.mock` in a test file in the diff, confirm whether the config sets `isolate: false`; if so, look for a matching unmock in `afterAll` and a shuffled-order run.
- **Seen:** 1 (pr-review, 2026-10)

### L-047: Mapped API errors on the client without checking what the proxy in between forwards
- **Area:** error handling, API contracts, testing
- **Pattern:** The client mapped the API's 400 messages, but a proxy turned 400s into 500s with a generic body for most roles, so the mapping only worked for one role. Separately, the API refused an "all items already handled" batch with a 400 instead of returning a zero count, so a skip was reported as a failure.
- **Root cause:** Tests mocked the client helper below the proxy, and the design followed the API's documented counts without reading its edge-case branches.
- **Rule:** Before mapping error statuses or messages, trace them through every hop to the browser for each role, and read the API handler's branches for empty or all-skipped input. Test at least one case through the proxy.
- **Check:** For each status or message branch in client error handling, find the proxy code for that status and role, and the API branch that produces it.
- **Seen:** 1 (pr-review, 2026-10)

### L-050: Safety gates were wired only in an untested entry point
- **Area:** testing, scripts, separation of concerns
- **Pattern:** An operator script's pure planning and per-item steps were unit tested, but the rules that combine them (apply only with a reviewed plan, filter to the reviewed items, ask before writing, write the rollback record before the first item, exit non-zero on failure) lived only in the entry function that parses arguments and touches files. They were correct when written, but a refactor could have broken any of them without a test failing.
- **Root cause:** Treated the entry point as glue and checked the gates by reading it, without noticing that the safety controls added in review lived only there.
- **Rule:** Keep a script's entry point to argument parsing, file I/O and wiring. Put the orchestration in a function that takes its data access, storage, prompt and record sink as parameters, with a mode type that makes unsafe combinations unrepresentable (e.g. apply requires the reviewed set), and test each gate there. Confirm each test fails when its gate is removed.
- **Check:** For each script or job entry point in the diff, list the conditions it checks and the order of its side effects; flag any that only that untested function enforces.
- **Seen:** 1 (pr-review, 2026-11)

### L-051: Checked an allowlist object with `in`
- **Area:** validation, JavaScript
- **Pattern:** Checked an input string against an object-literal allowlist with `in`, which also matches inherited properties (`constructor`, `__proto__`). Crafted input passed the check, and the lookup returned a function instead of a value.
- **Root cause:** Treated the object literal as a set without considering its prototype chain.
- **Rule:** Check untrusted keys against a `Set`, a `Map`, or an own-property test (`Object.hasOwn` / `hasOwnProperty.call`), never `in` or a bare index. Test with `constructor` and `__proto__`.
- **Check:** For each `x in OBJ` or `OBJ[input]` in the diff where the input is untrusted, confirm it uses an own-property or Map/Set lookup.
- **Seen:** 1 (pr-review, 2026-11)

### L-052: Relied on a shared helper to store a field without checking that it does
- **Area:** audit/logging, API contracts
- **Pattern:** New code passed a field to a shared logging helper whose parameter type declared it, but the helper copied only a few named fields into the stored record and dropped the rest. The new feature's records were missing the data it was written to capture. The gap was noticed in review but filed as an existing bug because the helper was untouched.
- **Root cause:** Took the helper's parameter type as proof the field was stored, and judged the gap by who wrote the helper rather than by whether the new feature depended on it.
- **Rule:** When new code depends on a helper persisting or sending a value, read the helper down to what it actually writes, and add a test on the payload that reaches the storage call (not on the arguments passed to the helper). A defect in untouched code becomes part of the change once the change relies on it; fix it there or narrow the change.
- **Check:** For each field the diff passes to a logging, persistence or request helper, confirm the helper's body forwards it to the final write, and that some test asserts it in that write's payload. Flag any helper whose parameter type has fields its body never reads.
- **Seen:** 1 (pr-review, 2026-11)

### L-053: Made an untrusted response type honest by erasing its shape
- **Area:** types, API contracts, validation
- **Pattern:** Replaced a response generic that was asserted but never checked with an opaque `Record<string, unknown>` / `unknown` so the runtime checks below it were required. Developers lost the only in-code description of the response, and property typos compiled.
- **Root cause:** Treated the request generic only as a type claim to remove, not also as documentation of the contract.
- **Rule:** For unvalidated responses, keep the field names and drop only the value types (e.g. `type Unchecked<T> = { [K in keyof T]?: unknown }`), typed from the same interface the function returns after validation, so there's one source of truth.
- **Check:** For each request generic or cast in the diff typed `unknown`, `any` or `Record<string, unknown>`, confirm the expected fields are still named by a type developers can navigate to.
- **Seen:** 1 (user-feedback, 2026-11)

### L-054: Cherry-picked a string key without checking what it matches on the target branch
- **Area:** git, configuration, cross-branch ports
- **Pattern:** Ported a config entry whose keys are matched by string against definitions elsewhere (column ids, field paths). The cherry-pick applied cleanly, but the target branch still used the older definitions, so nothing matched and the feature silently disappeared for every user.
- **Root cause:** Treated a clean apply as proof the change fit the target, without looking at the code the values are matched against, which was outside the diff.
- **Rule:** When porting a value that is looked up by string (ids, keys, paths, event names), find what it is compared with on the target branch and confirm it still matches; if the two sides drifted, keep the target's value. Add a test that runs the real matching rule over the real definitions so a mismatch fails.
- **Check:** For each cherry-picked change to a config map, registry or key-to-handler table, search the target branch for the consumer that matches those keys and compare both sides; look for a test that feeds the actual definitions through the lookup.
- **Seen:** 1 (self-review, 2026-11)

### L-056: Stopped selecting a field but left the result type declaring it
- **Area:** types, API contracts
- **Pattern:** Swapped one field for another in a query's selection set. The query's result type was a broad entity type intersected with extras, so it still declared the dropped field as required, and a mapper labelled the rows with the full entity type. Code reading the old field would have compiled and received `undefined`.
- **Root cause:** Changed the selection without checking how the result type was built; assumed the type tracked the query.
- **Rule:** When a query stops selecting a field, remove it from the result type (e.g. `Omit<Entity, 'field'> & {...}`) and retype any callbacks that label those rows with the broader entity type. Let the typecheck find the readers.
- **Check:** For each field removed from a selection set in the diff, find the type the result is cast to; if it still declares the field (directly or through an intersected base type), flag it.
- **Seen:** 1 (pr-review, 2026-11)

### L-057: Appended default sort keys without checking overlap with the user's sort
- **Area:** data access, pagination
- **Pattern:** Added fixed tiebreakers (name, then id) after the user's sort to make pagination stable. When the user sorted by one of the tiebreaker fields, the order list named that field twice with opposite directions, relying on unverified server behavior for duplicates.
- **Root cause:** Built the list as "user input + defaults" without considering inputs that overlap the defaults.
- **Rule:** When appending default keys (sort tiebreakers, default filters, default fields) to user-supplied ones, skip defaults that name a field the user already set, and test with a user value equal to each default.
- **Check:** For each `[userValue, ...defaults]` composition in the diff, ask what happens when the user's value uses a default's key; confirm a test covers it.
- **Seen:** 1 (pr-review, 2026-11)
