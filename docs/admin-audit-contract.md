# Admin Audit Contract

`AdminLogs` is the append-oriented audit store for AfifeAdmin business data
changes, soft deletes, toggle updates, failed mutation attempts, and
database-side effects. `UsersLog` is reserved for authentication and
account-security events such as login success/failure, logout, password changes,
password-reset notifications, and e-mail changes.

## Required coverage

- Page visits and GET/HEAD requests are not logged.
- Successful MVC actions do not create a second action log. Their INSERT, UPDATE,
  toggle, and soft-delete details are already captured by SQL audit triggers.
- The global MVC action filter records only failed non-GET mutation attempts as
  `OperationType = FailedAction` and excludes `AccountController`.
- Mutation endpoints must be marked with `[AdminMutationAudit]`; failed read-only
  table, search, similarity-check, and export requests are not business audit events.
- SQL audit triggers record every successful INSERT, UPDATE, soft delete, and any
  physical delete that reaches an AFTER trigger.
- `OldValues` and `NewValues` are JSON arrays containing every database column for
  every row affected by one SQL statement. Bulk updates remain one atomic audit
  event and do not lose any row.
- `EntityKey` contains the primary-key values of all affected rows.
- Trigger/procedure side effects use the same correlation ID and operation name as
  the initiating request. `Source = DatabaseTrigger` identifies nested effects.
- Toggle switches are ordinary UPDATE statements and therefore receive complete
  old/new snapshots.
- Failed create/update/delete operations are recorded by the MVC filter with
  `IsSuccessful = 0`. Exception chains, ModelState validation errors, HTTP errors,
  JSON `success=false` messages, and generic fail-popup messages are retained.
- Failed-action `AttemptedValues` contain the fields submitted for the record in
  sanitized form. Passwords, hashes, tokens, secrets, Base64 data, and raw image bytes are redacted.
- `UserId`, `Username`, IP address, user agent, HTTP method, route, controller,
  action, application, and Turkey-local occurrence time are retained when the
  operation originates from AfifeAdmin.
- Direct SQL or another application is still audited for successful DML. Request
  fields may be null, while `Application` falls back to SQL Server `APP_NAME()`.
- `AdminLogs` and `UsersLog` are excluded from data-audit triggers to prevent
  recursive logging and preserve the separation between business and security
  logs.

## Mandatory checklist for future database work

This checklist applies to every future table, entity, controller mutation, direct
SQL statement, trigger, stored procedure, background job, import, and shared
application that writes to AfifeAdmin:

1. Keep the operation inside the global soft-delete contract. Do not physically
   delete the business row or its audit history.
2. Every new business table must have `IsPublished`, be mapped in `AfifeContext`,
   and receive an audit trigger by re-running
   `sql/create-admin-audit-logging.sql` after the table is created.
3. Do not disable or bypass `TR_AdminAudit_*` triggers. Trigger and stored-procedure
   side effects must remain audited with the initiating correlation ID.
4. Mark every new state-changing MVC endpoint with `[AdminMutationAudit]` so a
   failed attempt retains `AttemptedValues`, validation errors, and the failure
   reason. Do not mark read-only table, search, export, or GET endpoints.
5. Do not manually insert a successful MVC action log. Successful writes are
   represented only by their SQL `Insert`, `Update`, or `SoftDelete` snapshots.
6. Keep password, hash, token, secret, Base64, and raw image request values redacted
   in failed-action logs. Full successful database snapshots remain restricted
   audit data and must never be returned from normal endpoints.
7. Keep login, logout, password, password-reset, and similar account-security
   events in `UsersLog`; keep business mutations in `AdminLogs`.
8. Preserve `DisableSqlOutputClauseForAuditedTables` in `AfifeContext`. Every mapped
   audited table has a trigger, so EF Core SQL Server `OUTPUT` must remain disabled.
9. Applications sharing this database must set the documented `Admin*`
   `SESSION_CONTEXT` values before DML when user, username, IP, route, and
   correlation metadata are required. DML is still audited without them, but actor
   metadata cannot be inferred by SQL Server.
10. Verify each new write flow in a rollback transaction: the primary row, nested
    trigger/procedure changes, full old/new JSON, actor context, and correlation ID
    must all be present. Verify a failed application attempt separately with
    `IsSuccessful = 0` and populated `AttemptedValues`.

## Transaction behavior

Database audit rows participate in the same transaction as the data change. A
rolled-back or failed statement cannot retain a misleading successful data-change
log. The MVC action log is written through a separate connection after the action,
so application failures are retained with their detailed reason.

SQL Server cannot commit a table row from a failed transaction autonomously.
Failures executed directly in SSMS or another application therefore require that
application to write a failure event or SQL Server Extended Events. AfifeAdmin
operations are covered by the MVC failure logger.

## Deployment

Every mapped table has a trigger after this script is installed. `AfifeContext`
therefore disables the SQL Server `OUTPUT` clause centrally for all entity types;
otherwise EF Core `SaveChanges` fails with SQL Server error 334. Do not remove
`DisableSqlOutputClauseForAuditedTables` while these triggers are enabled.

The deployment script also soft-deletes legacy successful `MvcAction` and
`PageView` duplicates; failed actions and SQL data-change history remain published.

Run `sql/create-admin-audit-logging.sql` on every shared database. The script is
idempotent and creates or refreshes one audit trigger for every existing user
table except `AdminLogs` and `UsersLog`. Re-run it after adding a new table.

Because full-row snapshots include binary image columns and password hashes,
access to `AdminLogs` must be restricted to authorized administrators, retention
must be monitored, and logs must never be exposed through ordinary application
responses.
## Restricted audit viewer

The hidden audit console is documented in `docs/audit-log-viewer-user-guide.md`.
It has no application navigation entry, requires the authenticated `Coordinator`
role, disables response caching, deliberately reads published and soft-deleted log
history, and redacts sensitive snapshot values for display. Invalid filter values
must fail closed rather than returning an unfiltered result set.