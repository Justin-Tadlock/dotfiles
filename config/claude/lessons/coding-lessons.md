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

<!-- Lessons start below. Next ID: L-001 -->
