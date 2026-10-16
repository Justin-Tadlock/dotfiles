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

<!-- Promoted (removed from this file): L-007 → CLAUDE.md "Git & Branching" -->
<!-- Lessons start below. Next ID: L-010 -->

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
- **Pattern:** Destructured fields named by a declared TypeScript response type that didn't match the real payload, yielding `undefined` → `NaN`/`0`. Two successive fixes failed for the same reason.
- **Root cause:** Treated a compile-time type as proof of runtime shape; nothing validated it.
- **Rule:** When a value from an external response is wrong, inspect a real captured payload before hypothesizing. Validate external responses at the boundary with a runtime schema, and fix stale types once confirmed.
- **Check:** For new reads of external response fields in the diff, confirm a runtime schema or verified sample backs the declared type.
- **Seen:** 1 (self-review, 2026-08)

### L-008: Authorized a sanitized copy of the input but acted on the raw input
- **Area:** authorization, validation
- **Pattern:** An access-check helper filtered out malformed ids (wrong type, null) before checking, then returned "allowed" for the remainder; the caller performed the action on the original unfiltered list, so smuggled ids were acted on without being checked.
- **Root cause:** Treated the helper's input normalization as harmless cleanup, without confirming the checked set equals the acted-on set.
- **Rule:** Authorization helpers must reject (deny) any malformed element rather than drop it, and handlers must validate the full input at the boundary before both checking and acting on that same validated value.
- **Check:** For each access check in the diff, compare the exact variable passed to the check with the one passed to the mutation; flag any `.filter`, dedupe-with-drop, or type guard inside the check that could shrink the set.
- **Seen:** 1 (pr-review, 2026-10)

### L-009: Row-level write check satisfiable by the row being written
- **Area:** authorization, row-level security
- **Pattern:** A permission's post-write check required "a membership row for me exists on the parent", while the role could update the membership table's foreign keys, so moving its own membership row to another parent satisfied the check and granted access.
- **Root cause:** Reviewed the filter/check expressions in isolation without asking whether the write itself can change the facts the check relies on.
- **Rule:** For any table that grants access (memberships, assignments, roles), deny writes to its foreign-key columns for the roles it scopes, and test that a role cannot reassign itself.
- **Check:** For each insert/update permission in the diff, list the columns the check depends on through relationships; flag any that are writable by the same role, especially on membership/assignment tables.
- **Seen:** 1 (pr-review, 2026-10)
