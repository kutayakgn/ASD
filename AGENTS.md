# Repository invariants

- Treat `AwardCategories.CategoryCode` and `PlayStatuses.StatusCode` as shared,
  immutable integration contracts. Do not renumber, delete, repurpose, or reseed
  their canonical rows from migrations, application startup, or test-data scripts.
- Read `docs/reference-data-contracts.md` before changing award-category,
  play-status, candidate, voting, or seed-data behavior.
- Read `docs/play-source-and-voting-contracts.md` before changing `RecordType`,
  play visibility, jury voting, ticket-fee, assignment, or blacklist behavior.
- `Plays.RecordType` is immutable provenance: `0` means Kunye Giris and `1`
  means AfifeAdmin. It is not a visibility or activation flag.
- `KunyeGirisStatus` and `JuriOylamaStatus` are editable only for `RecordType = 0`.
  Both must remain false for `RecordType = 1`.
- Candidates and votes are allowed only for `RecordType = 0`; ticket fees and
  jury assignments are allowed for both source types.
- For each `JuryId + PlayId + AwardCategoryCode + RoleCode` group, `JuryVotes`
  may contain only one physical row regardless of `IsPublished`. Recording a vote
  for another old/current candidate must delete the previous candidate vote row.
- `IsPublished` is the soft-delete flag for candidates and votes. Normal queries
  must exclude rows where it is false.
- `PlayAwardCategories.IsActive` controls candidate availability and
  `JuryVotes.IsActive` controls vote calculation eligibility. Candidate activity
  changes synchronize non-deleted vote activity in both directions.
- Hard-deleting a candidate must cascade-delete all of its `JuryVotes` rows.
- Do not use `IsPublished` as an activity toggle. Candidate status controls must
  update `PlayAwardCategories.IsActive`.
- Read `docs/candidate-role-and-category-contracts.md` before changing category
  multiplicity, role identity, candidate replacement, or default category behavior.
- Every `RecordType = 0` play must have a system-managed category `1001` row whose
  `Candidate` equals `Plays.TheaterName`, `RoleCode = 0`, and `IsCurrent = 1`.
- `AwardCategories.MultiCandidate` controls simultaneous logical role slots. A
  replacement must reuse the role's stable `RoleCode`; do not generate a new code.
- Award-category placeholder assets are resolved by the stable convention
  `wwwroot/images/awardCategoryPlaceholder/{CategoryCode}.svg`.
