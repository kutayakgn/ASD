# Candidate Role and Category Contracts

This document defines how `AwardCategories`, `PlayAwardCategories`, and
`JuryVotes` represent category multiplicity, role history, and votes. Read it with
`reference-data-contracts.md` and `play-source-and-voting-contracts.md`.

## Immutable category metadata

`AwardCategories.CategoryCode` remains the shared identity. Existing codes, IDs,
names, and meanings must not be renumbered, deleted, or repurposed.

`MultiCandidate` describes whether a play may have multiple simultaneous logical
candidate slots in the category:

| CategoryCode | MultiCandidate | Slot model |
| --- | --- | --- |
| 1001, 1002, 1007, 1008, 1009, 1010, 1011 | 0 | One logical slot per play/category |
| 1003, 1004, 1005, 1006, 1012 | 1 | Multiple role slots per play/category |

`MultiCandidate` does not limit historical rows. A single-slot category can keep
old candidate rows after a replacement, but only one row can be current.

`HasRoleAndPhoto` controls whether the add-candidate UI requires a role name
and offers an optional candidate photo. Its initial values mirror `MultiCandidate`;
changing the two metadata values independently requires a deliberate contract review.
Category 1001 is system-managed and is never offered by the add-candidate UI.

## System-managed category 1001

Every `Plays.RecordType = 0` (Kunye) play has exactly one canonical category 1001
row, even before any candidate data is entered. Its invariant values are:

- `Candidate = Plays.TheaterName`
- `Role = NULL`
- `RoleCode = 0`
- `IsCurrent = 1`
- `IsPublished` initially follows `Plays.IsPublished`

Changing `Plays.TheaterName` synchronizes the canonical row's `Candidate` value.
The canonical row cannot be edited or deleted directly. RecordType 1 admin plays
must not have any `PlayAwardCategories` row, including category 1001.

## Logical role identity

A candidate slot is identified by `PlayId + AwardCategoryCode + RoleCode`.
`RoleCode` is scoped to one play/category and is a stable slot identifier. It is
allocated once for a new role and must be reused by every replacement in that role;
it must never be randomly regenerated for a replacement.

For `MultiCandidate = 1`, `RoleCode` must be positive and `Role` must be present.
Within a play, a normalized role name cannot belong to two different logical RoleCodes, even across categories. Old/current candidates in the same logical role group must share the same Role value. Editing that Role updates every published row in the same PlayId + AwardCategoryCode + RoleCode group after explicit confirmation. The group rename must be executed as one set-based SQL statement so the role-integrity trigger never observes a temporary mixed-role group.

Within one play/category, one role name maps to one RoleCode and one RoleCode maps
to one role name. Different roles may each have a current candidate.

For `MultiCandidate = 0`, the category uses one logical slot, normally RoleCode 0,
and Role is empty. Legacy non-zero slot codes are preserved, but new records use 0.

## Replacement and publication

Adding a new role creates a current row. Replacing a role first changes the existing
current row to `IsCurrent = 0`, then inserts the new row with the same RoleCode and
`IsCurrent = 1`. Multiple old rows are allowed, but only one current row is allowed
per logical slot.

`IsCurrent` means current role holder. `IsActive` means the candidate is available and its votes are calculation-eligible. `IsPublished` is only the soft-delete flag. They are independent: an old candidate may remain active and votable, and a current candidate may be inactive.

## Vote behavior

A jury may have one published vote per
`JuryId + PlayId + AwardCategoryCode + RoleCode`. Voting for another old/current
candidate in the same role soft-deletes the previous vote row by setting
`IsPublished = 0` and `IsActive = 0`, then keeps the new vote as the published row.
Historical soft-deleted votes remain in the database. Votes in different RoleCodes
can coexist.

Unpublishing a candidate preserves related vote rows but changes their
`IsPublished` and `IsActive` values to 0. Republishing the candidate republishes
those preserved votes and aligns their `IsActive` values with the candidate, while
the single-published-vote trigger resolves any logical-role conflict. Physical deletes
and delete cascades are forbidden. Soft-deleting one vote does not activate or
otherwise change a vote for another candidate.

## Application flow

The add-candidate UI excludes category 1001. It asks for Role and offers Photo when the selected category has `HasRoleAndPhoto = 1`. `Yeni Aday` allocates a positive role code from 1-9999 that is unused by any published logical role in the play. `Aday/Rol Degisimi` identifies the selected current candidate by GUID, closes it, and inserts the replacement with exactly the same Role and RoleCode. The operation runs in a serializable transaction and the database constraints remain the final concurrency guard.

## Operational scripts

Run `sql/add-award-category-multiplicity-and-default-play-category.sql` once on each
shared database. It adds metadata, normalizes the canonical 1001 slot without
deleting legacy rows, backfills missing defaults, and installs enforcement triggers.

Run `sql/add-award-category-role-photo-metadata.sql` after the multiplicity migration.
It adds `HasRoleAndPhoto` without changing CategoryCode values and initially mirrors
the existing `MultiCandidate` metadata.

Run `sql/test-candidate-role-and-category-scenarios.sql` after the migration. Every
test is wrapped in a transaction and rolled back, so no test data remains.
