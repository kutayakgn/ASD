# Afife Reference Data Contracts

`AwardCategories.CategoryCode` and `PlayStatuses.StatusCode` are shared integration
contracts. They are consumed by this admin application and other applications that
use the same database.

Do not renumber, delete, repurpose, or automatically reseed these records in a
migration, test-data script, or application startup routine. New reference values
must be introduced deliberately and coordinated across all applications.

## Award categories

| CategoryCode | Id | CategoryName |
| --- | --- | --- |
| 1001 | `40000000-0000-0000-0000-000000000001` | Yılın En Başarılı Oyunu |
| 1002 | `40000000-0000-0000-0000-000000000002` | Yılın En Başarılı Yönetmeni |
| 1003 | `40000000-0000-0000-0000-000000000003` | Yılın En Başarılı Kadın Oyuncusu |
| 1004 | `40000000-0000-0000-0000-000000000004` | Yılın En Başarılı Erkek Oyuncusu |
| 1005 | `40000000-0000-0000-0000-000000000005` | Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu |
| 1006 | `40000000-0000-0000-0000-000000000006` | Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu |
| 1007 | `40000000-0000-0000-0000-000000000007` | Yılın En Başarılı Sahne Tasarımı |
| 1008 | `40000000-0000-0000-0000-000000000008` | Yılın En Başarılı Giysi Tasarımı |
| 1009 | `40000000-0000-0000-0000-000000000010` | Yılın En Başarılı Sahne Müziği |
| 1010 | `40000000-0000-0000-0000-000000000009` | Yılın En Başarılı Işık Tasarımı |
| 1011 | `40000000-0000-0000-0000-000000000012` | Yılın En Başarılı Hareket Düzeni (Kareografisi) |
| 1012 | `40000000-0000-0000-0000-000000000011` | Yılın En Başarılı Genç Kuşak Sanatçısı |

Category placeholder assets follow this stable convention:
`wwwroot/images/awardCategoryPlaceholder/{CategoryCode}.svg`.

## Play statuses

| StatusCode | Id | StatusName | StatusColor |
| --- | --- | --- | --- |
| 1 | `30000000-0000-0000-0000-000000000001` | Oylama Aktif | `#27ae60` |
| 2 | `30000000-0000-0000-0000-000000000002` | Değerlendirmeyecek Oyun | `#d9322d` |
| 3 | `30000000-0000-0000-0000-000000000003` | Başvuru Yapmayacak Oyun | `#2ca9e8` |
| 4 | `30000000-0000-0000-0000-000000000004` | Sahnelenmeyecek Oyun | `#ac48ed` |
| 5 | `30000000-0000-0000-0000-000000000005` | Başvurusu Olmayan Oyun | `#ffffff` |
| 6 | `30000000-0000-0000-0000-000000000006` | Sistemde Aktif Değil | `#ffc400` |

Application rules must compare codes by meaning, not by row order or display name.

## Admin-created play invariants

See `docs/play-source-and-voting-contracts.md` for the complete two-application
source, visibility, voting, assignment, and ticket-fee contract.

`Plays.RecordType = 1` identifies an admin-created play. These rows must always
have `JuriOylamaStatus = 0` and `KunyeGirisStatus = 0`, and their `StatusCode`
must not be `1` (`Oylama Aktif`). The UI and application endpoints must not allow
either status toggle to be changed for these rows.

Admin-created plays cannot have `PlayAwardCategories`, `JuryVotes`, or `Blacklist` records and
cannot participate in candidate voting. They may have `JuryAssignedPlays` and
`JuryGameTicketFees` records. An existing play with candidates cannot be converted
to `RecordType = 1` until those candidate records are removed.

Run `sql/enforce-admin-play-status-rules.sql` to normalize existing records and
enforce these rules with database check constraints.
Run `sql/enforce-admin-play-candidate-rules.sql` to soft-delete invalid candidate/vote
records and install the cross-table enforcement triggers.

## Candidate multiplicity and role history

See `docs/candidate-role-and-category-contracts.md` for `MultiCandidate`, stable
RoleCode, replacement-history, and the system-managed category 1001 contract.
Category 1001 uses `Plays.TheaterName` as its canonical Candidate value.
## Candidate activity, soft-delete, and jury-vote invariants

`PlayAwardCategories.IsPublished` and `JuryVotes.IsPublished` are soft-delete flags.
Normal lists and calculations exclude rows where `IsPublished = 0`.

`PlayAwardCategories.IsActive` controls candidate availability.
`JuryVotes.IsActive` controls whether a non-deleted vote participates in calculations.
Changing candidate activity synchronizes activity for its non-deleted votes. Soft-deleting
a candidate preserves its physical row and soft-deletes linked votes. Republishing the
candidate republishes those preserved votes and aligns their `IsActive` values with the candidate.

The logical vote identity remains
`JuryId + PlayId + AwardCategoryCode + RoleCode`. Only one published vote may exist
for that group. Voting for another old/current candidate soft-deletes the previous
vote and preserves both physical rows as history.

The global rule for every table is documented in `soft-delete-contract.md`. Run
`sql/enforce-global-soft-delete.sql` after the earlier candidate migration so all
foreign keys and direct SQL operations follow the same no-hard-delete contract.