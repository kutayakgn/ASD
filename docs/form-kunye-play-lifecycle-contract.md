# Form to Kunye Play Lifecycle Contract

`dbo.Form` is owned by the Kunye Giris application and is the source record for
Kunye plays consumed by AfifeAdmin and the jury application. Read this document
before changing Form, seasons, Kunye plays, candidates, votes, ticket fees, jury
assignments, blacklists, rankings, or their triggers.

## Form schema

- `Form.Id` is a GUID. Legacy integer IDs are converted deterministically to
  `f0000000-0000-0000-0000-{legacy id padded to 12 digits}`.
- `Form.SeasonId` is a GUID foreign key to `Seasons.Id` with `ON DELETE NO ACTION`.
- `Form.SeasonId` is database-managed from `Form.CreatedDate`; callers may omit it.
- If seasons overlap, the matching season with the earliest end date is selected,
  then the latest start date and GUID are deterministic tie breakers.
- A CreatedDate outside every published season is rejected.
- Legacy `Active` is renamed to the domain flag `IsActive`.
- Legacy `Deleted` is removed. `IsPublished` is the only soft-delete flag.
- `ApplicationNumber` is unique only while `IsPublished = 1`.

## Form and play identity

`Plays.SourceFormId` is a nullable, unique foreign key to `Form.Id`. It is set only
for Form-created plays and requires `RecordType = 0`. `Plays.RecordType` remains
immutable provenance and is never changed by synchronization.

The Form-to-Play mapping is:

| Form | Plays |
| --- | --- |
| `Id` | `SourceFormId` |
| `RepertoireName` | `PlayName` |
| `TheatreName` | `TheaterName` |
| `CreatedDate` | `CreatedAt` |
| `UpdatedDate` | `UpdatedAt` |
| `Phone` | `Phone` |
| `ContactName`, fallback `ApplicantName` | `ContactPersonName` |
| `ContactPhone`, fallback `Phone` | `ContactPersonPhone` |
| `Email` | `Email` |

New active Forms create a published and active Kunye play with `RecordType = 0`,
`StatusCode = 1`, `JuriOylamaStatus = 1`, and `KunyeGirisStatus = 1`. The existing
system trigger creates category `1001` with `Candidate = Plays.TheaterName`,
`RoleCode = 0`, `IsCurrent = 1`, `IsActive = 1`, and `IsPublished = 1`.

An initially inactive Form does not create a play. Activating it creates the play
and category. Form field updates synchronize the mapped Play fields, while the
category-1001 trigger synchronizes its Candidate when TheaterName changes.

## Active and deleted states

`IsPublished` and `IsActive` remain different concepts:

- `Form.IsPublished = 0` means the Form is soft-deleted.
- `Form.IsActive = 0` means the Form exists but is unavailable to AfifeAdmin and
  jury business flows.
- A Form is effective only when both flags are `1`.
- A Form-sourced Kunye play always keeps `Plays.IsPublished = 1`, preserving the
  invariant that `RecordType = 0` plays cannot be soft-deleted.
- `Plays.IsActive = 0` hides the play without violating that invariant.
- Deactivation sets both play visibility statuses to `0` so external applications
  cannot treat the play as visible or open for voting.
- AfifeAdmin global query filters require both `Play.IsPublished` and
  `Play.IsActive`, and both `Form.IsPublished` and `Form.IsActive`.

## Dependent state snapshot

Before an effective Form becomes inactive, `FormLifecycleStates` records the exact
published/active state of its linked records. The following records are then made
unavailable:

| Table | Deactivation |
| --- | --- |
| `Plays` | Preserve `IsPublished=1`; set `IsActive=0` and both visibility statuses to `0` |
| `PlayAwardCategories` | Set `IsPublished=0`, `IsActive=0` |
| `JuryVotes` | Set `IsPublished=0`, `IsActive=0` |
| `JuryGameTicketFees` | Set `IsPublished=0` |
| `JuryAssignedPlays` | Set `IsPublished=0` |
| `Blacklist` | Set `IsPublished=0` |
| `Rankings` | Ranking refresh soft-deletes the projection row |

Reactivation restores only rows captured by that deactivation. A candidate that
was already inactive returns as inactive. A historical row already soft-deleted
before Form deactivation is not captured and is never accidentally restored.
Completed snapshot rows are retained with `IsPublished = 0`; they are never
physically deleted.

Database guard triggers reject new published candidates, votes, ticket fees, jury
assignments, or blacklists for an inactive Form-sourced play. Lifecycle restoration
uses a private session context marker and still passes existing uniqueness and
logical-vote triggers.

## Delete and restore

`DELETE FROM dbo.Form` is intercepted. It updates the Form to
`IsPublished = 0, IsActive = 0`, then runs the same dependent deactivation flow.
No Form, Play, candidate, vote, ticket, assignment, blacklist, ranking, snapshot,
or audit row is physically deleted.

Restoring a Form is explicit: set both `IsPublished = 1` and `IsActive = 1`.
Filtered uniqueness and vote-role rules are revalidated by the database while the
snapshot is restored.

## Statistics, rankings, and audit

- Season play counts include only `Plays.IsPublished = 1 AND IsActive = 1`.
- Season vote counts join through active/published candidates and plays.
- Rankings require an active, published Kunye play in addition to the existing
  candidate and vote eligibility rules.
- Form writes and every procedure/trigger side effect are captured in AdminLogs.
- `FormLifecycleStates` is a business table with `IsPublished`, a soft-delete
  filter, no-delete foreign keys, EF mapping, and an AdminLogs trigger.

## Deployment

Run in this order:

1. `sql/migrate-forms-to-kunye-play-lifecycle.sql`
2. `sql/create-seasons-and-statistics.sql`
3. `sql/create-rankings-projection.sql`
4. `sql/create-admin-audit-logging.sql`
5. `sql/test-form-kunye-play-lifecycle.sql`

The other Kunye application must use GUID Form IDs, stop reading/writing `Active`
and `Deleted`, use `IsActive` and `IsPublished`, and include `Plays.IsActive = 1`
in direct SQL play/voting/ticket lookups. Normal inserts may omit SeasonId because
the database derives it from CreatedDate.

## Verified scenarios

The rollback test script verifies these outcomes:

1. Existing Forms retain all physical rows and receive valid seasons, plays, and
   category-1001 rows.
2. Active Form insert derives SeasonId and creates its Kunye play/category.
3. Mapped Form updates propagate to Plays and category 1001.
4. Candidate, vote, ticket fee, assignment, and blacklist rows can exist while the
   Form is active.
5. `IsActive = 0` hides the play and soft-deletes/deactivates every dependent.
6. `IsActive = 1` restores exact previous states and refreshes Rankings.
7. Form DELETE remains a physical row and executes the same lifecycle.
8. An initially inactive Form creates no play until activated.
9. A CreatedDate outside published seasons is rejected without leaving a row.
10. A published child insert for an inactive Form play is rejected by the database.

All ten scenarios passed against the local AfifeAdmin database and the test left
zero persistent Form or Play rows.
