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
6. **Write and back up.** After approval, write the entry (using the next ID from the marker comment, and updating it), then commit only that file and push:
   - `git -C ~/dotfiles add config/claude/lessons/coding-lessons.md`
   - `git -C ~/dotfiles commit -m "lessons: <add|update> L-NNN <generic title>"`
   - `git -C ~/dotfiles push`
   - Never stage other files in the dotfiles repo as part of this step. If the push fails, report it; do not force-push.

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
- Curation changes follow the same propose → approve → commit → push flow as Capture.
