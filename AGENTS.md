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
- `JuryVotes.IsPublished` only controls calculation eligibility. Unpublishing a
  candidate must preserve its vote rows but set those rows to `IsPublished = 0`;
  republishing the candidate must reactivate the preserved votes automatically.
- Hard-deleting a candidate must cascade-delete all of its `JuryVotes` rows.
- `PlayAwardCategories.IsPublished` is the only candidate publication/status field.
  Do not recreate or reference the removed `PlayAwardCategories.IsActive` column.
- Award-category placeholder assets are resolved by the stable convention
  `wwwroot/images/awardCategoryPlaceholder/{CategoryCode}.svg`.
