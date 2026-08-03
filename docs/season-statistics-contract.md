# Season Statistics Contract

`Seasons` is the persisted source for the `/arsiv-karsilastirma` report. Normal
application queries include only rows where `IsPublished = 1`; deleting a season
means changing that flag to `0`, never physically deleting the row.

## Date ranges

Season statistics use a half-open interval: `CreatedAt >= SeasonStartDate` and
`CreatedAt < SeasonEndDate`. This keeps boundary timestamps from belonging to two
seasons. `KunyeRegistrationStartDate`, `KunyeRegistrationEndDate`,
`VotingStartDate`, and `VotingEndDate` are scheduling metadata and do not change
the aggregation range.

The initial rows begin with the 2018-2019 season. Their sample schedule is:

- Season: September 1 through May 1 of the following year.
- Kunye registration: September 1 through December 31.
- Voting: January 1 through April 30 of the following year.

## Management date rules

Season management is available under `/diger-ayarlar`. A season name is derived as
`SeasonStartDate.Year/SeasonEndDate.Year` and is never persisted separately.

- `SeasonStartDate` must be strictly earlier than `SeasonEndDate`.
- Published seasons use inclusive conflict detection: their start/end ranges may not
  overlap or share even one boundary date. Editing excludes only the season being edited.
- Kunye registration may start on the season start date but never before it.
- Kunye registration end must be strictly later than its start and no later than
  the season end date.
- Voting start and end must remain inside the inclusive season boundaries, and
  voting start must be strictly earlier than voting end.
- Season deletion is always a soft delete (`IsPublished = 0`).
- Every season create, date-range update, or soft delete recalculates `Form.SeasonId` from `Form.CreatedDate`. Forms with no matching published season keep `SeasonId = NULL`; deleting a season therefore clears or reassigns all references to it.
- `PlayCount`, `ActivePlayCount`, and `VoteCount` remain database-managed values;
  management forms must never accept or write these counters.

Run `sql/enforce-season-management-date-rules.sql` and then
`sql/sync-form-season-assignments.sql` on existing databases to align constraints and Form season assignments with these rules.
## Counters

- `PlayCount`: published and active `Plays` whose `CreatedAt` is in the season interval.
- `ActivePlayCount`: the same published and active plays with `StatusCode = 1`.
- `VoteCount`: published and active `JuryVotes` whose own `CreatedAt` is in the
  season interval.

`dbo.usp_RefreshSeasonStatistics` is the only SQL routine that recalculates these
counters. Set-based triggers on `Plays` and `JuryVotes` call it for the affected
date range when `CreatedAt`, `IsPublished`, `StatusCode`, or `IsActive` changes.
A season range change also recalculates its counters. Trigger updates never change
`IsPublished` and never physically delete data.

Run `sql/create-seasons-and-statistics.sql` to create the table, indexes, procedure,
triggers, initial rows, and initial counter values. The script is idempotent and
preserves existing published season rows.