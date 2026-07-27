# Global Soft-Delete Contract

This contract applies to every database table and every application sharing the
AfifeAdmin database.

## Meaning

- `IsPublished = 1` means the row is non-deleted and available to normal queries.
- `IsPublished = 0` means the row is deleted logically but retained physically.
- `IsActive` and domain status fields are not delete flags.
- Normal EF queries exclude soft-deleted rows. Deliberate audit or restore flows
  must opt in explicitly with `IgnoreQueryFilters()`.

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

## Restore

Restore is a deliberate operation, not the inverse side effect of another delete.
Before setting `IsPublished = 1`, validate filtered unique indexes and all domain
rules. Restoring a candidate synchronizes its preserved votes according to the
candidate/vote contract, and the single-published-vote rule still applies.

Run `sql/enforce-global-soft-delete.sql` once on every shared database after deploying
this code. The script adds missing flags, removes the remaining delete cascade,
updates vote triggers, and installs direct-SQL soft-delete guards.