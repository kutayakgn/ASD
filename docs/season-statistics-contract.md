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