---
name: start-task
description: Plan-then-implement workflow for a feature or fix. Use when the user says "Start task". Loads the branch's task doc, runs a security-focused design discussion, and implements only after the user says "Let's implement" or "Start implementing".
---

# Start Task

Follow these steps in order.

## 1. Load task context

- Run `git branch --show-current` to get the branch name.
- Check whether `.claude/<branch-name>.md` exists (e.g. `.claude/feat-add-monthly-calendar-cache.md`).
- If it exists, read it in full. It holds the task summary, intended interfaces, types, functions, and constraints the user drafted.
- If it does not exist, ask the user to describe the task before proceeding.

## 2. Brainstorm (no code yet)

Read `~/.claude/reference/correctness.md`, `~/.claude/reference/security.md`, and `~/.claude/lessons/coding-lessons.md` first. Then collaborate with the user to refine the plan:

- Summarize your understanding of the task from the doc and the conversation. Mark anything you inferred rather than read as "Unverified".
- Propose interfaces, types, function signatures, API route shapes, GraphQL operations (if applicable), and which existing patterns in the codebase apply (cite the files).
- Ask clarifying questions about anything ambiguous, especially data flow, role-based access, error handling, and edge cases.
- Point out inconsistencies or gaps in the plan, and suggest alternatives where it conflicts with existing patterns or the standards in CLAUDE.md.
- Enumerate the paths from the correctness checklist: success, failure, partial failure, empty/loading, concurrency/races.
- Think like a penetration tester. For every proposed interface, function, route, and GraphQL operation, state:
  - **Trust boundary:** where untrusted input enters and where it is validated.
  - **Authorization:** who may call it, and how ownership/tenant scoping is enforced server-side.
  - **Abuse cases:** at least the relevant attacks (IDOR, privilege escalation, mass assignment, filter bypass, injection, enumeration) and how the design blocks each.
- Name the coupling: which existing modules the design touches, and which consumers of changed contracts must be checked.
- List the lessons relevant to this design by ID.

Iterate until the user explicitly signals they are satisfied.

## 3. Implement

Start only after the user says "Let's implement" or "Start implementing".

- Follow the agreed design. Flag any new abstraction or deviation before making it.
- Implement the agreed validation and authorization as part of the feature, not as a follow-up.
- Write tests for the abuse cases from brainstorming (another user's ID, a missing role, malformed input, a forbidden filter field) alongside the happy-path tests.
- Finish with the "Definition of done" in CLAUDE.md, including the **Check** of every relevant lesson against the diff.
