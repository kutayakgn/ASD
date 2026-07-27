# Repository invariants

- Treat `AwardCategories.CategoryCode` and `PlayStatuses.StatusCode` as shared,
  immutable integration contracts. Do not renumber, delete, repurpose, or reseed
  their canonical rows from migrations, application startup, or test-data scripts.
- Read `docs/soft-delete-contract.md` before changing any delete action, entity,
  relationship, migration, trigger, cleanup, test-data, or restore behavior.
- Read `docs/reference-data-contracts.md` before changing award-category,
  play-status, candidate, voting, or seed-data behavior.
- Read `docs/play-source-and-voting-contracts.md` before changing `RecordType`,
  play visibility, jury voting, ticket-fee, assignment, or blacklist behavior.
- No application or SQL path may physically delete a database row. Every table
  uses `IsPublished`: `1` is non-deleted and `0` is soft-deleted. All foreign keys
  use `ON DELETE NO ACTION`; delete cascades are forbidden.
- Every screen, API, lookup, report, export, and authentication query must exclude
  `IsPublished = 0`; never use `IgnoreQueryFilters()` in a normal application flow.
- Every newly inserted entity must start with `IsPublished = 1`. The DbContext
  enforces this and database tables must have `DEFAULT (1)` for the column.
- Business unique indexes must be filtered with `WHERE IsPublished = 1`, allowing
  any number of soft-deleted historical duplicates. Primary keys and immutable FK
  target codes remain globally unique and are not filtered.
- Restores must be explicit and must revalidate uniqueness and domain invariants
  before setting `IsPublished` back to `1`.
- `Plays.RecordType` is immutable provenance: `0` means Kunye Giris and `1`
  means AfifeAdmin. It is not a visibility or activation flag.
- Kunye (`RecordType = 0`) plays can never be soft-deleted and must always
  remain `IsPublished = 1`; only AfifeAdmin (`RecordType = 1`) plays may be
  soft-deleted.
- `KunyeGirisStatus` and `JuriOylamaStatus` are editable only for `RecordType = 0`.
  Both must remain false for `RecordType = 1`.
- Candidates and votes are allowed only for `RecordType = 0`; ticket fees and
  jury assignments are allowed for both source types.
- For each `JuryId + PlayId + AwardCategoryCode + RoleCode` group, only one
  published `JuryVotes` row may exist. Recording a vote for another old/current
  candidate soft-deletes the previous vote row and preserves its history.
- `PlayAwardCategories.IsActive` controls candidate availability and
  `JuryVotes.IsActive` controls vote calculation eligibility. Candidate activity
  changes synchronize non-deleted vote activity in both directions.
- Soft-deleting a candidate must preserve and soft-delete its `JuryVotes` rows.
  Physical candidate and vote deletion is forbidden.
- Do not use `IsPublished` as an activity toggle. Candidate status controls must
  update `PlayAwardCategories.IsActive`.
- Read `docs/candidate-role-and-category-contracts.md` before changing category
  multiplicity, role identity, candidate replacement, or default category behavior.
- Every `RecordType = 0` play must have a system-managed category `1001` row whose
  `Candidate` equals `Plays.TheaterName`, `RoleCode = 0`, and `IsCurrent = 1`.
- `AwardCategories.MultiCandidate` controls simultaneous logical role slots. A
  replacement must reuse the role's stable `RoleCode`; do not generate a new code.
- AwardCategories.HasRoleAndPhoto controls required role input and optional
  candidate-photo input; category 1001 is never user-selectable.
- Award-category placeholder assets are resolved by the stable convention
  `wwwroot/images/awardCategoryPlaceholder/{CategoryCode}.svg`.