## "Start Task" Workflow

When the user says "Start task", follow these steps in order:

### 1. Load Task Context

- Run git branch --show-current to get the current branch name.
- Check whether .claude/<branch-name>.md exists (e.g., `.claude/feat-add-monthly-calendar-cache.md`).
- If the file exists, read it in full. This file contains the task summary, intended interfaces, types, functions, and constraints the user has drafted.
- If the file does not exist, ask the user to describe the task before proceeding.

### 2. Brainstorming Phase

Do NOT write any code yet. Instead, collaborate with the user to refine the plan:

- Summarize your understanding of the task based on the doc and any prior conversation.
- Identify and propose: interfaces, types, function signatures, API route shapes, GraphQL query/mutation needs (if applicable), and which existing patterns (controllers, hooks for React projects, etc.) apply.
- Ask clarifying questions about anything ambiguous — especially around data flow, role-based access, error handling, and edge cases.
- Point out any inconsistencies or gaps in the plan.
- Suggest alternatives when a proposed approach conflicts with existing patterns or project preferences.
- Think like a penetration tester to find holes in the designs and make sure that the proposed designs are rock-solid.
- Apply the "Security & Penetration-Testing Standards" section below to every proposed interface, function, route, and GraphQL operation. For each one, explicitly state:
  - **Trust boundary:** where untrusted input enters and where it is validated.
  - **Authorization:** who may call it, and how ownership/tenant scoping is enforced server-side.
  - **Abuse cases:** at least the relevant attacks (IDOR, privilege escalation, mass assignment, filter bypass, injection, enumeration) and how the design blocks each.
- Review the "Coding Lessons Learned" file and call out any lessons relevant to this design.

Iterate on this discussion until the user explicitly signals they are satisfied and ready to proceed.

### 3. Implementation Phase

Only begin writing code after the user says one of the following phrases, "Let's implement", "Start implementing".

Follow the agreed design from the brainstorming phase. Do not introduce new abstractions or deviate from the plan without flagging it first.

Implement the validation and authorization agreed in the design as part of the feature, not as a follow-up. Write tests for the abuse cases identified during brainstorming (e.g., another user's ID, a missing role, malformed input, a forbidden filter field) alongside the happy-path tests.

Before declaring implementation complete, run the **Check** of every relevant lesson in the "Coding Lessons Learned" file against the diff and fix any hits.

---

## Additional Information and Preferences

### Generic Development Preferences

In order of priority:

1. Prefer best practices and standards for the language being used.
2. Prefer native solutions over introducing third-party dependencies (only add third-party dependencies when absolutely necessary).
3. Prefer functional programming practices
4. Prefer simple, easy to maintain solutions over complex solutions.
5. Prefer test driven development; make as much code as possible testable.
6. Prefer battle-tested design patterns when designing solutions, especially where architecture is relevant for better code quality and maintenance.
7. When analyzing code, be mindful of potential refactor work that could be done to improve code quality, ease of development, and improving maintainability.

### Front-end projects

- Prefer best practices and standards specifically according to React, Next.js and TypeScript.
- Prefer async/await functions over .then() chaining in javascript and TypeScript projects
- Prefer flexible parameter inputs, but be strict on return types of functions.

### Back-end projects

- Prefer proper RESTful API routes and practices
- Prefer REST best practices and standards.
- Prefer async/await functions over .then() chaining in javascript and TypeScript projects

### Correctness & Resilience Checklist

Every piece of code written or edited must meet this bar. Apply it twice: during brainstorming (enumerate the paths: success, failure, partial failure, empty/loading, concurrency/races) and as a final adversarial self-review of the finished diff before calling the work done, not only when a reviewer flags something.

- **Simplicity & reuse:** Use the smallest solution that solves the actual problem. Before adding an abstraction, parallel code path, service method, or plumbing layer, look for an existing mechanism that already does the job and extend it.
- **Separation of concerns:** Keep routes thin, controllers/hooks focused on orchestration, and data access (DB, REST, GraphQL, caches) separate from business and presentation logic, so a bug is clearly either "the data layer returns/stores the wrong thing" or "the consumer handles it wrong", never both tangled together. Pass deeply needed state via props, dependency injection, or context, not side-channel refs or globals.
- **Termination:** Every retry loop, polling loop, effect-driven state machine, cron job, or queue consumer must have a provably terminating condition and must not wait on a state that may never occur. Guard against overlapping runs.
- **Defensive boundaries:** Validate the runtime shape of data at system boundaries (requests, DB results, tokens/claims, external API responses, cached data). A TypeScript type is not proof a value exists. When coalescing (`??`, `||`, defaults), confirm the fallback does not mask a materially different state ("unknown" vs. "zero", "errored" vs. "not found"). When a design or a claim to the user depends on what external or stored data looks like (an API response, a field's meaning, a legacy storage format), inspect real captured data or the code that wrote it first, including every code path and earlier version that wrote that field, not just the current one. Static types, field names and assumptions are not evidence. Before reporting a defect, predicting a test result, or explaining an observed one, confirm that the path runs for the inputs involved (gates, flags, orchestration), take environment facts (roles, permissions, secrets, data sources) from the authoritative configuration rather than from code, confirm that both sides of a comparison cover the same records (same input, run, version), and read the writer of each count or field to learn what it measures. Otherwise state the claim conditionally and give the check that decides it. When matching results from an external provider back to local records, scope the match by ownership (tenant/project plus an identity the provider guarantees), not by the inputs a job declared, since the provider's job configuration can be stale; log dropped or ambiguous items with counts instead of skipping them silently, and test an item from an owned but undeclared record. Show the cause of missing matches in captured data (provider results, stored configuration, local rows) before designing around it or stating it in comments or commit messages.
- **Unknown is not negative:** Model fetch-derived state explicitly (loading / success / not-found / error) and never let a fallback value stand in for "unknown". Keep "should we render" separate from "what do we tell the user"; errors get their own message and a retry. An absence check that grants access must fail closed when absence can't be established: "not permitted to see" is not "nothing exists". Never write a test asserting that an error produces a negative result.
- **Every writer:** When changing how a value is derived or who may write it, find every place that produces, inserts, copies or removes/archives it (not just callers of one helper), including share/copy/clone flows that carry it over, and change them together or give each a supported path. Before denying or restricting a write path, list the flows that use it and give each a supported path. Follow the corrected value into the lookups that consume it and make both sides use the same normalization. For insert-if-absent flows, check what each remaining writer would create if it ran first.
- **Matching pipelines:** When adding a broader fallback to a multi-step matching pipeline, run it only on items no existing step resolves (including exact-match steps that run after it), and never let it rewrite an item an exact step would match. Make each decision depend only on data that always arrives together (the item and its variants), not on what else is in the batch. Never persist a fallback result where a higher-priority step will read it back as authoritative; if it must persist, make the exact-match step outrank every step that reads it. If a guard skips a tier for a whole group because one item matched earlier, propagate that match to the group's other items. Test an item that both the exact step and the fallback could resolve, in one batch and split across batches in both orders, plus a re-run.
- **Async error paths:** Every async function and promise has a real catch path that produces a typed, meaningful error (server) or visible feedback with a retry where sensible (client). No bare `await` in handlers. Do not hold a transaction open across an external call.
- **Feedback on every path:** Every reachable path (success, validation failure, not-found, error, partial failure) returns a correctly typed, meaningful response or UI state: loading indicators, disabled in-flight controls, success/error messages. A success status with an ambiguous or empty body on failure is a bug.
- **Testability:** Structure code so the above can be unit tested in isolation: pure functions for logic, mockable data/external-API modules, and hooks/components that don't need the whole app mounted. Each security test must reach the rule it names: assert the preconditions that get past earlier checks and fallbacks, and confirm it fails when the rule is disabled. Expected-failure tests must fail only for the vulnerable outcome.

### Git & Branching

- When cherry-picking onto a long-diverged branch, don't treat conflicts or missing references (helpers, enum members, parameters, files) as simple missing-file problems. First check which history each side assumes:
  - Isolate the commit's real change with `git show <sha> -- <path>`; surrounding conflict context may just be stale.
  - Find where a missing reference came from (`git log --diff-filter=A <source-branch> -- <path>`), and whether that commit is on the target (`git merge-base --is-ancestor <commit> HEAD`).
  - If the target is already ahead (the code was extracted or moved there), keep the target's side and drop the incoming duplicate.
- Default to the narrowest fix that preserves the target branch's current behavior, not the source branch's evolved behavior. Ask before pulling in unrelated features to satisfy a dependency.
- After resolving, run the typecheck and confirm every new reference exists on the target branch.

### Security & Penetration-Testing Standards

Design and write all code as if it will be penetration tested. Treat every value that crosses a trust boundary (HTTP requests, GraphQL arguments, URL/query params, headers, cookies, form data, webhooks, message queues, files, third-party API responses, and data read from storage that users can write) as hostile until validated.

#### Input Validation

- Validate at the boundary with a runtime schema (use the project's existing validation library, or native checks if none exists). TypeScript types alone are not validation.
- Use allow-lists, not deny-lists: explicit allowed fields, enums, formats, lengths, numeric ranges, and array sizes.
- Reject unknown fields rather than silently passing them through (prevents mass assignment, e.g., a client setting `role`, `ownerId`, `isAdmin`, `tenantId`, or `createdAt`).
- Map validated input to explicit internal types/DTOs; never spread raw request bodies into database writes or downstream calls.
- Internal functions should take narrow, already-validated types so invalid states are unrepresentable (e.g., branded IDs, discriminated unions) rather than re-checking loosely typed input.
- Use parameterized queries / ORM bindings only; never build SQL, NoSQL, shell commands, file paths, regexes, or URLs by concatenating user input. Guard against path traversal and SSRF where paths or URLs are user-influenced.
- Fail closed: on validation or auth failure, reject the request; never fall back to a permissive default.

#### Authorization & Data Access

- Authenticate and authorize on the server for every request; never rely on the UI hiding something, client-side role checks, or obscure IDs.
- Derive identity (user ID, tenant/org ID, roles) from the verified session/token only; never trust identity or ownership values supplied by the client.
- Check authorization against the specific resource, not just the operation (prevent IDOR): "can this user read/modify *this* record?"
- Scope queries at the data layer (e.g., `WHERE owner_id = :sessionUserId AND tenant_id = :sessionTenantId`) instead of fetching first and filtering afterward.
- For updates/deletes, verify ownership in the same query or transaction as the write to avoid TOCTOU races.
- Authorize the exact identifiers a mutation acts on. Access-check helpers must deny (not drop) malformed elements. Whenever an id is derived from the input (a parent, linked, or backing resource), run the access check on the derived id too, and audit sibling handlers that make the same derivation.
- Before relying on a record to grant or order access, confirm the caller can't write the columns the rule depends on through any path (insert, update, upsert, or a copy/clone flow) (foreign keys, `id`, timestamps, soft-delete flags, URL or reference fields). If they can, the rule is forgeable; fix the write permission first. For tables that grant access (memberships, assignments), deny writes to their foreign keys for the roles they scope, and test that a role cannot reassign itself.
- When an authorization decision is made in a query, test it against a real database with allowed and denied fixtures for every role (including inactive users and cross-tenant rows), running every query path the check can take. A missing table or column permission is an error, not an empty result.
- Apply least privilege for roles, service accounts, API keys, and database users.
- Return the same response for "not found" and "not authorized" where existence itself is sensitive, to prevent enumeration.

#### GraphQL-Specific

- Enforce authorization in resolvers (or a shared auth layer/directive applied consistently), including field-level checks on sensitive fields and nested/relationship resolvers — not only on the top-level query.
- Server-side scoping filters (owner, tenant, visibility, soft-delete) must be applied unconditionally and combined with `AND` so client-supplied filters cannot override, widen, or `OR` around them.
- Allow-list which fields are filterable and sortable, and which operators are allowed per field; never pass client filter objects straight through to the ORM/database (prevents filtering or sorting on hidden fields such as `passwordHash`, `role`, or another tenant's data, and blocks operator injection like `$where`/`$regex`).
- Mutation inputs must not include server-controlled fields (owner, tenant, role, status transitions the user may not perform); validate allowed state transitions explicitly.
- Enforce pagination limits, query depth/complexity limits, and batching/alias limits to prevent resource exhaustion and data scraping.
- Ensure DataLoaders and caches are keyed per request/user so data never leaks between users.
- Disable introspection and verbose errors in production unless intentionally exposed.

#### Errors, Logging & Secrets

- Never leak stack traces, SQL, internal IDs, or validation internals to clients; return generic messages and log details server-side.
- Never log secrets, tokens, passwords, or sensitive PII.
- No hard-coded secrets; read them from environment/secret management.

#### Front-end

- Avoid `dangerouslySetInnerHTML` and unsanitized HTML/URLs (including `javascript:` URLs); validate redirects against an allow-list to prevent open redirects.
- Never expose secrets via public env vars (e.g., `NEXT_PUBLIC_*`); keep privileged logic in server components, route handlers, or server actions — and authorize server actions like any other public endpoint.
- Protect cookie-based state-changing requests against CSRF; use `HttpOnly`, `Secure`, and `SameSite` cookies.

## "Review PR" Workflow

When the user says "Review PR", follow these steps in order:

### 1. Gather Context

- Run git branch --show-current to get the current branch name.
- Run git remote show origin | grep 'HEAD branch' to detect the default base branch (e.g., main, staging, `dev`).
- Run git diff <default-branch>...HEAD to get the full diff against the detected base branch.
- Run git log <default-branch>...HEAD --oneline to get the commit history for this branch.
- Check whether .claude/<branch-name>.md exists (extracted from the branch name using the same pattern as "Start Task"). If it exists, read it — use it to understand the intended design and constraints so the review is grounded in what was actually planned.

### 2. Review Phase

Analyze the diff thoroughly. For each file changed, evaluate:

Correctness

- Logic errors, off-by-one errors, null/undefined dereferences
- Unhandled edge cases or error paths
- Async/await issues, missing error handling, unhandled promise rejections
- Injection risks, missing input validation
- Hard-coded secrets or credentials
- Auth/permission checks missing or incorrectly applied

Security (Penetration-Test Review)

Review the diff as an attacker would, against the "Security & Penetration-Testing Standards" section. For each new or changed entry point, try to break it:

- Can input bypass validation (unknown fields, wrong types, oversized values, unexpected enums, null/empty, unicode/encoding tricks)?
- Can a user read, modify, or delete another user's or tenant's data by changing an ID, filter, sort, or nested selection (IDOR)?
- Can a client-supplied GraphQL filter widen, override, or `OR` around server-enforced scoping, or filter/sort on fields it shouldn't see?
- Can a mutation set server-controlled fields (owner, tenant, role, status) or perform a disallowed state transition (mass assignment / privilege escalation)?
- Are nested resolvers, field resolvers, and DataLoaders authorized and scoped per user?
- Are pagination, depth, and complexity limits enforced?
- Do errors or responses leak internal details or reveal whether a resource exists?
- Are there tests that prove the abuse cases are rejected, not just that the happy path works?

Any missing authorization, scoping bypass, or exploitable validation gap is 🔴 Critical.

Code Quality

- Violations of SOLID principles
- Opportunities to apply design patterns (Factory, Builder, Adapter, etc.)
- Stateful code that could be made functional
- Code that is harder to test than it needs to be

TypeScript/React/Next.js Correctness

- Incorrect or overly broad types (e.g., `any`)
- Missing or incorrect dependency arrays in hooks
- Unnecessary re-renders or missing memoization
- Violations of React/Next.js best practices
- Variables and parameters that could throw TypeScript errors (such as required variables that could be undefined from the caller)

Test Coverage

- Missing unit tests for new logic
- Untested edge cases
- Test structure inconsistencies with existing patterns (vitest, vi.hoisted, `@testing-library/react`)
- Make sure that any code that uses fake timers properly and reset to using system timers after tests (such as a beforeEach with vi.useFakeTimers(), and a afterEach with vi.useRealTimers()).

Consistency with Task Plan

- If a .claude/<branch-name>.md file was found, flag any deviations from the agreed interfaces, types, or approach that were not previously discussed.

Refactor Opportunities

- Note any existing code touched by this PR that could be improved, without blocking the review.

Lessons Learned

- Run the **Check** of every lesson in the "Coding Lessons Learned" file against the diff. Report hits as normal issues, tagged with the lesson ID (e.g., `[L-004]`).

### 3. Report Phase

Present findings in the following format:

#### Summary

A 2-3 sentence overview of what the PR does and your overall assessment. Include the detected base branch so it's clear what the diff was measured against.

#### Issues

Group by severity:

- 🔴 Critical — Must fix before merging (bugs, security issues, broken logic)
- 🟡 Warning — Should fix (code quality, missing tests, type issues)
- 🔵 Suggestion — Optional improvements (refactor opportunities, minor style)

For each issue, include:

- The file and line/function it relates to
- A clear description of the problem
- A concrete suggestion for how to fix it

#### Verdict

One of:

- ✅ Ready to push — No critical issues found
- ⚠️ Push with caution — Warnings present but no blockers
- 🚫 Do not push — Critical issues must be resolved first

### 4. Capture Lessons

After the report, follow the "Capture" steps of the "Lessons Learned" workflow for any 🔴 or 🟡 issue in code Claude wrote.

## "Lessons Learned" Workflow

Turns review findings into generic, reusable rules so the same class of mistake is not repeated. Lessons live in a single global file that is backed up to a **public** git repository, so every lesson must be fully sanitized.

The lessons file is imported here:

@~/.claude/lessons/coding-lessons.md

(Physical location: `~/dotfiles/config/claude/lessons/coding-lessons.md`, symlinked to `~/.claude/lessons`.)

### Triggers

Run the Capture steps when any of these happen:

- A "Review PR" finds a 🔴 or 🟡 issue in code Claude wrote.
- The user gives review feedback (their own or a teammate's PR comments) on code Claude wrote.
- Claude finds a defect in its own code during self-review, testing, or debugging.
- The user says "Capture lesson".

### Capture

1. **Find the root cause.** Ask "why did I write it this way?" until reaching the faulty assumption or skipped step, not the symptom. "Missing auth check on route X" is a symptom; "assumed shared middleware covered every route without verifying" is a root cause.
2. **Generalize.** Restate the mistake and the rule so they apply to any codebase using the same language, framework, or pattern. If the lesson only makes sense with project context, it is not a lesson: skip it.
3. **Deduplicate.** If an existing entry has the same root cause, increment **Seen**, append the source and month, and sharpen the rule if needed instead of adding a new entry.
4. **Sanitize.** Apply every Sanitization Rule below, then the leak test.
5. **Propose.** Show the user the exact new or changed entry text and wait for approval. Never write without approval.
6. **Write and commit.** After approval, write the entry (using the next ID from the marker comment, and updating it), then commit only that file:
   - `git -C ~/dotfiles add config/claude/lessons/coding-lessons.md`
   - `git -C ~/dotfiles commit -m "lessons: <add|update> L-NNN <generic title>"`
   - Never stage other files in the dotfiles repo as part of this step.
   - Do NOT push. The user pushes manually; remind them that there are unpushed lesson commits.

Skip one-off slips (typos, a wrong variable name) that do not reflect a reusable mistake.

### Sanitization Rules

Lessons are public and must be NDA-safe. An entry must NOT contain:

- Names of companies, clients, employers, products, projects, repositories, teams, internal services, internal packages, or codenames.
- People's names, usernames, or emails.
- File paths, branch names, PR/issue/ticket numbers, commit hashes, URLs, domains, IP addresses, or hostnames.
- Database, table, collection, column, queue, topic, or environment variable names from a project.
- API endpoint paths, GraphQL type/field names, or other schema details from a project.
- Business rules, domain concepts, feature names, or data that hints at what the product does.
- Code copied or paraphrased from a project. Examples must be written fresh, a few lines at most, using neutral placeholders (`resource`, `item`, `userId`, `fetchThing`).
- Secrets, credentials, tokens, or data samples of any kind.

Allowed: public languages, frameworks, and libraries (e.g., TypeScript, React, Next.js, vitest, Zod, Prisma), general patterns and vulnerability classes (IDOR, TOCTOU, mass assignment), and a month-level date with a source type.

**Leak test:** before proposing, ask "Could someone who knows my employer or clients recognize the project, product, or codebase from this entry?" If yes, or unsure, generalize further or drop it.

### Apply

- **Start Task:** during brainstorming, list the lessons relevant to the design.
- **Implementation:** before declaring done, run each relevant lesson's **Check** against the diff.
- **Review PR:** run every lesson's **Check** as part of the review.

### Curate

- When a lesson reaches **Seen: 3**, propose promoting its rule into the permanent standards sections of this file and removing the entry from the lessons file.
- Keep the lessons file under ~40 entries. When it grows past that, propose merging overlapping entries and removing ones that have been promoted or no longer apply.
- Curation changes follow the same propose → approve → commit flow as Capture.
- Project-level memory is for project-specific context only. Generic coding lessons always go to the global lessons file, never to a project's memory.
