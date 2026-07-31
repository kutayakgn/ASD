# Rankings Projection Contract

`dbo.Rankings` is a database-managed projection. It is not a user-editable
business table. Read this document before changing plays, candidates, votes,
ranking formulas, ranking triggers, or ranking reports.

## Eligible rows

There is exactly one published ranking row for every candidate/category row that
meets all of these conditions:

- The related `Plays` row has `RecordType = 0`, `IsPublished = 1`, and `IsActive = 1`.
- The `PlayAwardCategories` row has `IsPublished = 1`, `IsCurrent = 1`, and
  `IsActive = 1`.

Old candidates (`IsCurrent = 0`), inactive candidates, soft-deleted candidates,
admin-created plays, and soft-deleted plays are excluded. When a previously
eligible candidate becomes ineligible, its ranking row is preserved with
`IsPublished = 0`. If it becomes eligible again, the same projection row is
reactivated and recalculated.

Only `JuryVotes` rows with `IsPublished = 1` and `IsActive = 1` participate in
calculations.

## Calculations

- `NumberOfActiveVote`: count of eligible votes for the candidate/category row.
- `ArithmeticMean`: arithmetic average of eligible `JuryVotes.Score` values.
- `ArithmeticVariance`: sample variance (`VAR`) of eligible scores. SQL Server
  calculates it as `SUM((score - average)^2) / (vote count - 1)`. A single
  eligible vote therefore has a null variance.
- `ConfidenceValue`: variance-derived confidence band. It is `1` for variance
  greater than or equal to `6.064`, `2` for `[4.987, 6.064)`, `3` for
  `[4.141, 4.987)`, and `4` below `4.141`. A row without a variance has a null
  confidence value. Higher values therefore represent stronger confidence.
- `TrimmedMean`: when at least three eligible votes exist, scores are ordered
  ascending and exactly one lowest and one highest vote are excluded. The
  remaining scores are averaged:
  `(SUM(score) - MIN(score) - MAX(score)) / (vote count - 2)`. Tied extremes
  still remove only one row from each end. One or two eligible votes produce a
  null trimmed mean because no valid trimmed set remains.
- `ArithmeticRank`: descending `RANK()` of `ArithmeticMean`.
- `TrimmedRank`: descending `RANK()` of `TrimmedMean`.

Ranks are calculated across all eligible rows sharing the same immutable
`AwardCategoryCode`. Equal means share the same rank and the following rank may
contain a gap. Rows without eligible votes have null means, variance, and ranks;
their `NumberOfActiveVote` is zero.

## Report ordering

The rankings screen never exposes arbitrary column sorting. Trimmed and arithmetic
views order descending by their selected mean with null metrics last. Confidence
views order `ConfidenceValue` descending because `4` is the strongest confidence,
then use `TrimmedMean` descending as the tie breaker. Candidate and play names
provide deterministic final ordering. The visible sequence number is the row's
position in this selected report ordering across server-side pages. Ranking exports include the active-vote total score before the vote count. Arithmetic and confidence reports also expose sample variance. Confidence is rendered as `value/4`; vote drill-downs include only published, active votes and are paged server-side.
## Write ownership

- `dbo.usp_RefreshRankings` is the only supported writer.
- `TR_Plays_RefreshRankings`, `TR_PlayAwardCategories_RefreshRankings`, and
  `TR_JuryVotes_RefreshRankings` call the procedure after relevant changes.
- The procedure takes a session application lock and uses an internal session
  authorization marker while writing.
- `TR_Rankings_BlockManualWrite` rejects direct INSERT and UPDATE statements.
- `TR_Rankings_BlockManualDelete` rejects direct DELETE statements. No ranking
  row is physically deleted.
- DML permissions are denied to `public`; SELECT and procedure execution remain
  available. Database owners/sysadmins must still follow this contract.
- Application entity properties have private setters and are read-only.

The procedure performs a full category-aware refresh because one score change can
change ranks for every candidate in that award category. It updates only rows
whose persisted values changed.

## Audit and deployment

Run these scripts in order:

1. `sql/create-rankings-projection.sql`
2. `sql/create-admin-audit-logging.sql`

The second script installs `TR_AdminAudit_dbo_Rankings`, so procedure and
trigger-generated ranking changes retain complete old/new snapshots and the
initiating correlation context. Verify changes with rollback-based tests.

`sql/seed-ranking-formula-test-cases.sql` is an optional, persistent, idempotent
formula test seed. It uses two previously empty categories of the `Kon Perdes`
play and 33 dedicated jury users. Test set 1 must produce 32 votes, arithmetic
mean `6.28125`, sample variance `5.11189516129032`, trimmed mean `6.3`, and
confidence `2`. Test set 2 must produce 33 votes, arithmetic mean
`5.81818181818182`, sample variance `4.77840909090909`, trimmed mean
`5.83870967741935`, and confidence `3`.
