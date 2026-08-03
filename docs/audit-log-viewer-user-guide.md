# Audit Log Viewer User Guide

## Security and access

The viewer is intentionally absent from the header, menus, buttons, and normal site navigation. It is available only to an authenticated account carrying the `Coordinator` role. Knowing the URL is not sufficient without a valid admin session. Responses are marked `no-store` and pages use `noindex`, `nofollow`, and `noarchive`.

The viewer lists every database column from `AdminLogs` and `UsersLog`, including `IsPublished = 0` audit-history rows. Passwords, hashes, tokens, secrets, Base64 fields, and raw image data inside JSON snapshots are replaced with `[REDACTED]` at display time. Database values are not modified.

## Deployment checklist

1. Run the versioned EF migration resources in `Migrations/Scripts` after every business-table schema addition. This creates or refreshes the successful INSERT, UPDATE, soft-delete, and database-side-effect triggers.
2. Run the versioned EF migration resources in `Migrations/Scripts`. It creates the viewer filter indexes and returns any business table missing its generated audit trigger.
3. The missing-trigger result set must contain zero rows.
4. Review the metadata-completeness result sets. Direct SSMS operations can legitimately lack HTTP/user fields, but application-originated records should contain request metadata.
5. Restart AfifeAdmin after deploying the application code.

## AdminLogs endpoint

Base URL:

```text
https://HOST/__afife-audit-console/admin-logs
```

Supported query parameters use exact matching except date boundaries:

| Parameter | Format | Meaning |
| --- | --- | --- |
| `correlationId` | GUID | One correlated request and its trigger side effects |
| `username` | text | Exact admin username |
| `operationType` | text | Examples: `Insert`, `Update`, `SoftDelete`, `FailedAction` |
| `schemaName` | text | Usually `dbo` |
| `tableName` | text | Exact database table name, such as `Plays` |
| `occurredFrom` | `yyyy-MM-ddTHH:mm:ss` | Inclusive Turkey-local lower boundary |
| `occurredTo` | `yyyy-MM-ddTHH:mm:ss` | Inclusive Turkey-local upper boundary |
| `actionName` | text | Exact MVC action name |
| `page` | integer | Page number; default `1` |
| `pageSize` | `1..100` | Records per page; default `25` |

Examples:

```text
/__afife-audit-console/admin-logs?operationType=Update&tableName=Plays
/__afife-audit-console/admin-logs?username=admin&occurredFrom=2026-08-01T00:00:00&occurredTo=2026-08-03T23:59:59
/__afife-audit-console/admin-logs?schemaName=dbo&tableName=PlayAwardCategories&actionName=EditCandidate&page=1&pageSize=50
/__afife-audit-console/admin-logs?correlationId=11111111-2222-3333-4444-555555555555
/__afife-audit-console/admin-logs?operationType=FailedAction&actionName=EditPlayStatus
```

Multiple parameters are combined with logical `AND`. Results are ordered by `OccurredAt` descending.

## UsersLog endpoint

Base URL:

```text
https://HOST/__afife-audit-console/user-logs
```

Supported query parameters:

| Parameter | Format | Meaning |
| --- | --- | --- |
| `userId` | GUID | User affected by the security event |
| `actorUserId` | GUID | Admin/user who initiated the event |
| `username` | text | Exact username |
| `occurredFrom` | `yyyy-MM-ddTHH:mm:ss` | Inclusive Turkey-local lower boundary |
| `occurredTo` | `yyyy-MM-ddTHH:mm:ss` | Inclusive Turkey-local upper boundary |
| `application` | text | Exact application name, normally `AfifeAdmin` |
| `correlationId` | GUID | Correlated security event |
| `page` | integer | Page number; default `1` |
| `pageSize` | `1..100` | Records per page; default `25` |

Examples:

```text
/__afife-audit-console/user-logs?username=admin&application=AfifeAdmin
/__afife-audit-console/user-logs?userId=11111111-2222-3333-4444-555555555555
/__afife-audit-console/user-logs?actorUserId=11111111-2222-3333-4444-555555555555&occurredFrom=2026-08-01T00:00:00
/__afife-audit-console/user-logs?correlationId=11111111-2222-3333-4444-555555555555&pageSize=100
```

## Audit coverage rules

- Successful business INSERT/UPDATE/soft-delete operations are recorded by SQL triggers with complete `OldValues` and/or `NewValues` JSON snapshots.
- Trigger and stored-procedure side effects use the request correlation and are logged as separate affected-table records.
- Failed MVC mutations are recorded by `AdminActionAuditFilter` with sanitized attempted values, validation errors, HTTP metadata, failure reason, inferred primary table where possible, and route identity.
- Read-only table refresh, search, pagination, and Excel export POST endpoints do not create mutation logs.
- Login success/failure, logout, password change, and e-mail change remain in `UsersLog`; business changes remain in `AdminLogs`.
- `UserId`, `ActorUserId`, `OldValue`, and `NewValue` remain `NULL` when they are not meaningful for an event. Artificial placeholder data is not written merely to avoid `NULL`.