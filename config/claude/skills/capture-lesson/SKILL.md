---
name: capture-lesson
description: Turn a defect in code Claude wrote into a sanitized, generic lesson in the public lessons file, or curate that file. Use when the user says "Capture lesson", when a review finds a 🔴/🟡 issue in Claude's code, when the user gives review feedback on Claude's code, or when Claude finds a defect in its own code.
---

# Capture Lesson

Turns review findings into generic, reusable rules so the same class of mistake is not repeated. Lessons live in `~/.claude/lessons/coding-lessons.md` (physically `~/dotfiles/config/claude/lessons/coding-lessons.md`), which is backed up to a **public** git repository, so every lesson must be fully sanitized.

Read the lessons file before starting.

## Capture

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

## Sanitization rules

Lessons are public and must be NDA-safe. An entry must NOT contain:

- Names of companies, clients, employers, products, projects, repositories, teams, internal services, internal packages, or codenames.
- People's names, usernames, or emails.
- File paths, branch names, PR/issue/ticket numbers, commit hashes, URLs, domains, IP addresses, or hostnames.
- Database, table, collection, column, queue, topic, or environment variable names from a project.
- API endpoint paths, GraphQL type/field names, or other schema details from a project.
- Business rules, domain concepts, feature names, or data that hints at what the product does.
- Code copied or paraphrased from a project. Examples must be written fresh, a few lines at most, using neutral placeholders (`resource`, `item`, `userId`, `fetchThing`).
- Secrets, credentials, tokens, or data samples of any kind.

Allowed: public languages, frameworks, and libraries (e.g. TypeScript, React, Next.js, vitest, Zod, Prisma), general patterns and vulnerability classes (IDOR, TOCTOU, mass assignment), and a month-level date with a source type.

**Leak test:** before proposing, ask "Could someone who knows my employer or clients recognize the project, product, or codebase from this entry?" If yes, or unsure, generalize further or drop it.

## Curate

- When a lesson reaches **Seen: 3**, propose promoting its rule into `~/dotfiles/config/claude/reference/correctness.md` or `reference/security.md` (whichever fits) and removing the entry from the lessons file. Do not promote into CLAUDE.md: it loads into every session and must stay short. Only propose a CLAUDE.md change if the rule is a short, universal principle missing from it.
- Keep the lessons file under ~40 entries. When it grows past that, propose merging overlapping entries and removing ones that have been promoted or no longer apply.
- Curation changes follow the same propose → approve → commit flow as Capture; stage only the files the change touches.
- Project-level memory is for project-specific context only. Generic coding lessons always go to the global lessons file, never to a project's memory.
