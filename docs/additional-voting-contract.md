# Additional Voting Contract

## Purpose

`AdditionalVotings` grants a one-time, date-bounded exception that lets eligible juries submit a missing vote or replace an existing vote for eligible plays. It does not change the normal season voting dates.

## Storage

- `AdditionalVotings` stores the inclusive start/end dates and the all-juries/all-plays scope flags.
- `AdditionalVotingJuries` stores explicit jury scope only when `AppliesToAllJuries = 0`.
- `AdditionalVotingPlays` stores explicit play scope only when `AppliesToAllPlays = 0`.
- `AdditionalVotingUsages` is written by the jury application when the right is consumed. `UsageType = 0` means a first vote and `UsageType = 1` means an existing vote was updated. A filtered unique index allows only one published usage per grant + jury + play, so the exception is genuinely one-time for each eligible play.
- "All" is represented by a flag, not by copying every current ID. Therefore users or plays added after the grant was created are included while the grant remains active and otherwise eligible.

## Eligibility

A grant is usable only when all conditions are true:

- The grant is published and active.
- The current Turkey date is between `StartDate` and `EndDate`, inclusive.
- The jury is published, active, and has `RoleCode = 2`.
- The play is published, active, and has `StatusCode = 1`.
- The jury/play is covered by the corresponding all-scope flag or a published junction row.

The jury application must determine whether the operation created the first vote or updated an existing vote and insert one published `AdditionalVotingUsages` row in the same transaction as the vote mutation.

## Lifecycle and audit

All four tables contain `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy`, `IsActive`, and `IsPublished`. `IsActive` controls usability; `IsPublished` is reserved for soft delete. All four tables follow the global soft-delete contract. Foreign keys use `ON DELETE NO ACTION`; physical cascade deletes are forbidden. Updating a grant soft-deletes prior scope junctions and inserts a new scope snapshot. Deleting a grant soft-deletes the grant, its scope rows, and its usage rows. Every mutation endpoint uses `AdminMutationAudit`, and `sql/create-admin-audit-logging.sql` must be rerun after creating these tables.
