# Security & Penetration-Testing Standards

Design and write all code as if it will be penetration tested. Treat every value that crosses a trust boundary (HTTP requests, GraphQL arguments, URL/query params, headers, cookies, form data, webhooks, message queues, files, third-party API responses, and data read from storage that users can write) as hostile until validated.

## Input Validation

- Validate at the boundary with a runtime schema (use the project's existing validation library, or native checks if none exists). TypeScript types alone are not validation.
- Use allow-lists, not deny-lists: explicit allowed fields, enums, formats, lengths, numeric ranges, and array sizes.
- Reject unknown fields rather than silently passing them through (prevents mass assignment, e.g., a client setting `role`, `ownerId`, `isAdmin`, `tenantId`, or `createdAt`).
- Map validated input to explicit internal types/DTOs; never spread raw request bodies into database writes or downstream calls.
- Internal functions should take narrow, already-validated types so invalid states are unrepresentable (e.g., branded IDs, discriminated unions) rather than re-checking loosely typed input.
- Use parameterized queries / ORM bindings only; never build SQL, NoSQL, shell commands, file paths, regexes, or URLs by concatenating user input. Guard against path traversal and SSRF where paths or URLs are user-influenced.
- Fail closed: on validation or auth failure, reject the request; never fall back to a permissive default.

## Authorization & Data Access

- Authenticate and authorize on the server for every request; never rely on the UI hiding something, client-side role checks, or obscure IDs.
- Derive identity (user ID, tenant/org ID, roles) from the verified session/token only; never trust identity or ownership values supplied by the client.
- Check authorization against the specific resource, not just the operation (prevent IDOR): "can this user read/modify _this_ record?"
- Scope queries at the data layer (e.g., `WHERE owner_id = :sessionUserId AND tenant_id = :sessionTenantId`) instead of fetching first and filtering afterward.
- For updates/deletes, verify ownership in the same query or transaction as the write to avoid TOCTOU races.
- Authorize the exact identifiers a mutation acts on. Access-check helpers must deny (not drop) malformed elements. Whenever an id is derived from the input (a parent, linked, or backing resource), run the access check on the derived id too, and audit sibling handlers that make the same derivation.
- Before relying on a record to grant or order access, confirm the caller can't write the columns the rule depends on through any path (insert, update, upsert, or a copy/clone flow) (foreign keys, `id`, timestamps, soft-delete flags, URL or reference fields). If they can, the rule is forgeable; fix the write permission first. For tables that grant access (memberships, assignments), deny writes to their foreign keys for the roles they scope, and test that a role cannot reassign itself.
- When an authorization decision is made in a query, test it against a real database with allowed and denied fixtures for every role (including inactive users and cross-tenant rows), running every query path the check can take. A missing table or column permission is an error, not an empty result.
- A check that grants or widens access because a row is absent must hold even if that row was hard-deleted or cascade-deleted. List every way the row can disappear (hard deletes, `ON DELETE CASCADE`, cleanup jobs). If absence can't be established, fail closed, rely on evidence clients can't forge or remove (such as a storage-set timestamp), or have a person review each candidate, and make that reviewed list the required input of the step that acts on it (refusing anything not in it or changed since). When one absence check is found unsound, audit every sibling check in the same change that rests on a row existing.
- Apply least privilege for roles, service accounts, API keys, and database users.
- A lock, lease or "in progress" guard must not let the subject of a privileged action (deactivate, demote, revoke) hold that action off: let the privileged action take it over from a lower-privileged holder, limited to actions writing fields the holder never writes, and make the holder stop when it notices; its follow-up steps must lock and re-read the record's state before acting. Test the privileged action while the subject holds the lock.
- Return the same response for "not found" and "not authorized" where existence itself is sensitive, to prevent enumeration.

## GraphQL-Specific

- Enforce authorization in resolvers (or a shared auth layer/directive applied consistently), including field-level checks on sensitive fields and nested/relationship resolvers — not only on the top-level query.
- Server-side scoping filters (owner, tenant, visibility, soft-delete) must be applied unconditionally and combined with `AND` so client-supplied filters cannot override, widen, or `OR` around them.
- Allow-list which fields are filterable and sortable, and which operators are allowed per field; never pass client filter objects straight through to the ORM/database (prevents filtering or sorting on hidden fields such as `passwordHash`, `role`, or another tenant's data, and blocks operator injection like `$where`/`$regex`).
- Mutation inputs must not include server-controlled fields (owner, tenant, role, status transitions the user may not perform); validate allowed state transitions explicitly.
- Enforce pagination limits, query depth/complexity limits, and batching/alias limits to prevent resource exhaustion and data scraping.
- Ensure DataLoaders and caches are keyed per request/user so data never leaks between users.
- Disable introspection and verbose errors in production unless intentionally exposed.

## Errors, Logging & Secrets

- Never leak stack traces, SQL, internal IDs, or validation internals to clients; return generic messages and log details server-side.
- Never log secrets, tokens, passwords, or sensitive PII.
- No hard-coded secrets; read them from environment/secret management.

## Front-end

- Avoid `dangerouslySetInnerHTML` and unsanitized HTML/URLs (including `javascript:` URLs); validate redirects against an allow-list to prevent open redirects.
- Never expose secrets via public env vars (e.g., `NEXT_PUBLIC_*`); keep privileged logic in server components, route handlers, or server actions — and authorize server actions like any other public endpoint.
- Protect cookie-based state-changing requests against CSRF; use `HttpOnly`, `Secure`, and `SameSite` cookies.
