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

Iterate on this discussion until the user explicitly signals they are satisfied and ready to proceed.

### 3. Implementation Phase

Only begin writing code after the user says one of the following phrases, "Let's implement", "Start implementing".

Follow the agreed design from the brainstorming phase. Do not introduce new abstractions or deviate from the plan without flagging it first.

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
