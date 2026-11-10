---
name: review-pr
description: Full pre-push review of the current branch against its base branch (correctness, penetration-test security review, quality, tests, plan consistency, lessons). Use when the user says "Review PR".
---

# Review PR

Follow these steps in order.

## 1. Gather context

- `git branch --show-current` for the branch name.
- `git remote show origin | grep 'HEAD branch'` to detect the base branch (e.g. `main`, `staging`, `dev`).
- `git diff <base>...HEAD` for the full diff, and `git log <base>...HEAD --oneline` for the commits.
- If `.claude/<branch-name>.md` exists, read it so the review is grounded in what was planned.
- Read `~/.claude/reference/security.md`, `~/.claude/reference/correctness.md`, and `~/.claude/lessons/coding-lessons.md`.
- Run the project's typecheck, lint, and tests if they exist, and report the real output.

Every finding must cite `file:line` and be confirmed by reading the code path (and, where relevant, its callers and the config that gates it). If a finding can't be confirmed, report it as "Unverified" with the check that would settle it.

## 2. Review

For each changed file, evaluate:

**Correctness**
- Logic errors, off-by-one, null/undefined dereferences.
- Unhandled edge cases and error paths; async issues and unhandled rejections.
- Every item in the correctness checklist that applies to the change.

**Security (penetration-test review)**
Review as an attacker against `reference/security.md`. For each new or changed entry point, try to break it:
- Can input bypass validation (unknown fields, wrong types, oversized values, unexpected enums, null/empty, unicode/encoding tricks)?
- Can a user read, modify, or delete another user's or tenant's data by changing an ID, filter, sort, or nested selection (IDOR)?
- Can a client-supplied filter widen, override, or `OR` around server-enforced scoping, or filter/sort on hidden fields?
- Can a mutation set server-controlled fields or perform a disallowed state transition?
- Are nested/field resolvers and DataLoaders authorized and scoped per user? Are pagination, depth, and complexity limits enforced?
- Do errors or responses leak internals or reveal whether a resource exists?
- Do tests prove the abuse cases are rejected, not just that the happy path works?

Any missing authorization, scoping bypass, or exploitable validation gap is 🔴 Critical.

**Design & quality**
- Simplicity: is there a smaller solution, or an existing mechanism that should have been reused?
- Coupling: does the change reach into another module's internals, add shared mutable state, or change a contract without updating every consumer?
- Scope: does a bug fix include unrelated refactors that should be a separate PR?
- SOLID violations; stateful code that could be functional; code harder to test than it needs to be.

**REST/API**
- Method semantics and idempotency, status codes, error format, pagination, and versioning per the APIs section of CLAUDE.md.

**TypeScript / React / Next.js** (when applicable)
- Overly broad types (`any`), values that can be undefined where a caller requires them.
- Missing or incorrect hook dependency arrays; unnecessary re-renders.
- Framework best-practice violations.

**Tests**
- Missing tests for new logic or edge cases; tests that would still pass with the fix removed.
- Inconsistency with existing test patterns (e.g. vitest, `vi.hoisted`, `@testing-library/react`).
- Fake timers enabled without restoring real timers (`vi.useFakeTimers()` in `beforeEach` needs `vi.useRealTimers()` in `afterEach`).

**Consistency with the task plan**
- Flag deviations from the agreed interfaces, types, or approach in the task doc that were not discussed.

**Lessons**
- Run the **Check** of every lesson against the diff. Report hits as normal issues tagged with the lesson ID (e.g. `[L-004]`).

**Refactor opportunities**
- Note existing code touched by the PR that could be improved, without blocking the review. For design flaws, outline the refactor as a separate proposal.

## 3. Report

### Summary
Two or three sentences on what the PR does and the overall assessment. Name the base branch the diff was measured against, and the typecheck/lint/test results.

### Issues
Group by severity:
- 🔴 Critical: must fix before merging (bugs, security issues, broken logic).
- 🟡 Warning: should fix (quality, missing tests, type issues).
- 🔵 Suggestion: optional (refactors, minor style).

For each: `file:line` or function, the problem, and a concrete fix.

### Verdict
- ✅ Ready to push: no critical issues.
- ⚠️ Push with caution: warnings but no blockers.
- 🚫 Do not push: critical issues must be resolved first.

## 4. Capture lessons

For any 🔴 or 🟡 issue in code Claude wrote, follow the `capture-lesson` skill.
