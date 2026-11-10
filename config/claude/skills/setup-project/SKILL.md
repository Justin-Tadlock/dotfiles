---
name: setup-project
description: Create or update a project's Claude configuration (project CLAUDE.md, project hooks, and proposals for code guardrails) to match the global engineering standards. Use when the user says "Setup project", or asks to create, update, or audit a project's CLAUDE.md.
---

# Setup Project

Goal: give Claude the project facts it would otherwise have to guess, keep the project file short, and move checks from prose into tools. Every fact written must come from the repo (cite the file) or from the user. Never invent commands, paths, or roles.

## 1. Inventory (read-only)

- Find existing config: `CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/settings*.json`, `.claude/rules/`, `AGENTS.md`.
- Check whether `.claude/` and `CLAUDE.md` are committed or gitignored (`git check-ignore -v`). Committed files are shared with the team: changes to them are a team decision, so say so and keep personal preferences out of them.
- Read `package.json` scripts (or Makefile / pyproject / equivalent), the lint, typecheck, and test configs, the CI workflow, and the pre-commit hooks.
- Map the architecture from the code: entry points, layers, where auth, validation, data access, and error helpers live, and the authoritative role list (code enum vs. database; note any mismatch).
- Find every hop a request passes through (proxies, gateways, API routes forwarding to other services) and what each forwards.

## 2. Gap report

Compare the existing project file with `project-template.md` (in this skill's folder) and report:

- **Missing:** template sections with no content yet.
- **Wrong or stale:** commands that don't exist, paths that moved, patterns the code no longer follows. Verify each against the repo.
- **Duplicated globally:** generic rules already in `~/.claude/CLAUDE.md` or `~/.claude/reference/*.md`. Propose replacing them with a one-line pointer, keeping only the project-specific part (a concrete file, limit, or helper).
- **Too long:** aim for under ~1,000 words. Move long reference material (schemas, domain glossaries) into `.claude/rules/` or `docs/` files that the project file points to.

Show the proposed new file as a diff and wait for approval before writing.

## 3. Hooks (project settings)

Write to `.claude/settings.json` if `.claude/` is gitignored or the team agrees; otherwise use `.claude/settings.local.json` and make sure it is gitignored. Read the file first and merge; never replace it.

- The global Stop hook (`~/.claude/hooks/typecheck-on-stop.sh`) already typechecks changed TypeScript when the project has a `typecheck` script. Confirm the script exists; if it's named differently, note the name in the project file instead of duplicating the hook.
- Propose a PostToolUse hook on `Write|Edit` that runs the project's linter with autofix on the edited file only. Build the command from the project's own runner (e.g. `yarn -s eslint --fix "$f"`), guard by file extension, then follow the update-config verification flow: pipe-test, `jq -e` validate, prove it fires.
- Don't add hooks that run the full test suite on every edit; tests belong in the Definition of done.

## 4. Guardrail proposals (team changes, separate PRs)

These change shared tooling, so propose them as separate, small PRs with the trade-offs. Don't apply them as part of this setup:

- **Strict compiler flags:** check `tsconfig` for `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`. Run `tsc --noEmit` with each missing flag to count the errors it would raise, so the cost is known before proposing it.
- **Module boundaries:** if the architecture has layers (routes → controllers → services → data), propose lint rules that enforce the import direction (e.g. ESLint `no-restricted-imports`, which is built in, before third-party plugins).
- **Secret scanning:** check whether CI or pre-commit already scans for secrets; if not, propose one.
- **Mutation testing:** for security-critical modules (auth, access checks), propose a mutation-testing run on those paths only, to find tests that pass without checking behavior.

Report the current state of each one (present, absent, partial) with evidence.

## 5. Decisions folder

If the project has no place for decision records, propose one (e.g. `docs/decisions/` if committed, or `.claude/decisions/` if personal), and name it in the project file.
