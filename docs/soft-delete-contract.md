# Global Soft-Delete Contract

This contract applies to every database table and every application sharing the
AfifeAdmin database.

## Meaning

- `IsPublished = 1` means the row is non-deleted and available to normal queries.
- `IsPublished = 0` means the row is deleted logically but retained physically.
- `IsActive` and domain status fields are not delete flags.
- Every screen, API response, lookup, report, export, and authentication query must
  exclude soft-deleted rows. EF global query filters enforce `IsPublished = 1` for
  every mapped entity.
- `IgnoreQueryFilters()` is forbidden in normal application flows. A deliberate
  audit or restore flow may use it only when the soft-deleted data is explicitly
  required and must not expose those rows through a normal endpoint.
- Every newly added entity is forced to `IsPublished = 1` by the DbContext. Every
  table also has a database default of `1` for inserts that omit the column.

## Prohibited operations

Application code, migrations, maintenance scripts, triggers, tests, and seed scripts
must not physically delete rows. Do not use EF `Remove`, `RemoveRange`,
`ExecuteDelete`, SQL `DELETE`, `TRUNCATE`, or `ON DELETE CASCADE` as a business
operation. Foreign keys use `ON DELETE NO ACTION` so related history cannot vanish.

The DbContext converts accidental EF Deleted states to `IsPublished = 0`. Database
`INSTEAD OF DELETE` triggers provide a second guard for direct SQL and other
applications sharing the database.

## Related records

Soft delete does not physically cascade. A business operation may soft-delete
related rows explicitly when required by the domain. For example, soft-deleting a
candidate sets its linked votes to `IsPublished = 0`; all rows and foreign keys stay
intact. Soft-deleting a parent otherwise preserves child history unless a documented
domain rule says those children must also be soft-deleted.

`ON UPDATE CASCADE` is retained only for mutable shared alternate keys such as
CategoryCode, StatusCode, RoleCode, and GroupCode. Immutable GUID references and
image references may remain `ON UPDATE NO ACTION`.

## Vote replacement

For `JuryId + PlayId + AwardCategoryCode + RoleCode`, at most one published vote
may exist. Casting a vote for another old/current candidate soft-deletes the previous
vote (`IsPublished = 0`, `IsActive = 0`) and retains it as history. It never deletes
the physical row.


## Published-row uniqueness

Business uniqueness applies only to non-deleted rows. Unique indexes for jury votes,
jury assignments, ticket fees, candidates, current candidate slots, blacklist rows,
and role-scoped usernames/emails use `WHERE IsPublished = 1`. Any number of
soft-deleted historical rows may reuse those business-key values.

Primary keys remain globally unique. Shared alternate integration keys referenced by
foreign keys (`AwardCategories.CategoryCode`, `PlayStatuses.StatusCode`,
`Roles.RoleCode`, and `Group.Code`) also remain globally unique because SQL Server
foreign keys cannot reference filtered unique indexes and these codes are immutable
integration identities, not reusable business records.
## Play soft-delete cascade

Only an AfifeAdmin (`RecordType = 1`) play may be soft-deleted. A Kunye Giris (`RecordType = 0`) play must always remain `IsPublished = 1`; both the application and database reject attempts to delete or unpublish it. Deleting an eligible Admin play is one atomic soft-delete operation.
The play and its published `PlayAwardCategories`, `JuryVotes`,
`JuryAssignedPlays`, `JuryGameTicketFees`, and `Blacklist` rows are changed to
`IsPublished = 0`. Candidate and vote `IsActive` values are also changed to `0`.
No row is physically deleted; the transaction rolls back if any dependent update fails.

Form-sourced Kunye plays use `Plays.IsActive` for source availability. An inactive
or soft-deleted Form keeps its Kunye Play at `IsPublished = 1`, sets Play
`IsActive = 0`, and snapshot-soft-deletes its dependents. Explicit Form restore
restores only rows captured by that lifecycle operation. See
`docs/form-kunye-play-lifecycle-contract.md`.

## Restore

Restore is a deliberate operation, not the inverse side effect of another delete.
Before setting `IsPublished = 1`, validate filtered unique indexes and all domain
rules. Restoring a candidate synchronizes its preserved votes according to the
candidate/vote contract, and the single-published-vote rule still applies.

Run `sql/enforce-global-soft-delete.sql` once on every shared database after deploying
this code. The script adds missing flags, removes the remaining delete cascade,
updates vote triggers, and installs direct-SQL soft-delete guards.