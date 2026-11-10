# <Project name>

One or two sentences: what this service or app is, its stack, and what processes it runs.

Global standards: `~/.claude/CLAUDE.md`. This file holds only project facts.

## Verify

The commands the Definition of done runs. Name the one that runs everything.

```bash
<runner> typecheck    # ...
<runner> lint         # ...
<runner> test:unit    # ...
<runner> ttl          # all checks; run before saying done
```

How to run one test file, and any environment a test needs (Docker, TZ, env vars). Test commands must never point at shared or production credentials.

## Architecture

Layers and the direction imports may go (e.g. routes → controllers → services → data). Name the preferred pattern for new code and any legacy pattern not to copy.

| Directory | Responsibility |
|-----------|----------------|

## Authoritative sources

Where Claude must look instead of guessing:

- **Roles:** <the authoritative role list and where it lives; note if the code enum and the database differ>
- **Auth / identity:** <helper that derives the user from the session or token>
- **Validation:** <schema library and where boundary schemas live>
- **Data access:** <the only allowed DB entry point>
- **Errors:** <error types and response helpers>
- **Domain types:** <canonical type file>

## Trust boundaries and request path

Every hop from the client to storage, and what each one forwards (methods, statuses, bodies, headers). Project-specific traps (e.g. a handler wrapper that passes the raw body through).

## Testing conventions

File naming, unit vs. integration split, mocking pattern, shared test helpers.

## Project-specific pitfalls

Only things that are specific to this codebase (a pool size, a status field with two meanings, a cron that runs on one instance). Generic rules belong in the global reference files.

## Decisions

Decision records live in: <path>
