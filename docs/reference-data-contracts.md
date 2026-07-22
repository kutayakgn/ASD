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

## Candidate publication and jury-vote invariants

`PlayAwardCategories.IsPublished` is the only candidate publication/status field.
The former `PlayAwardCategories.IsActive` column must not be recreated or used.
`IsCurrent` remains separate: it identifies the current candidate in a role but does
not decide whether the candidate or vote participates in calculations.

The logical vote identity is:
`JuryId + PlayId + AwardCategoryCode + RoleCode`.

Only one physical `JuryVotes` row may exist for that group, regardless of the row's
`IsPublished` value. If a jury's vote moves from an old candidate to the current
candidate, or from the current candidate to an old candidate, the previous
candidate's `JuryVotes` row is physically deleted and the new candidate row is kept.

`JuryVotes.IsPublished` only controls whether that one existing vote is included in
calculations. Setting a vote to `IsPublished = 0` does not create, restore, or modify
another candidate vote.

When `PlayAwardCategories.IsPublished` changes from `1` to `0`, related
`JuryVotes` rows must be preserved for history but their `IsPublished` values must
be set to `0`. When the candidate is republished, those preserved votes must
automatically return to `IsPublished = 1`. A vote inserted or updated as published
for an unpublished candidate is automatically stored with `IsPublished = 0`.
Hard-deleting a candidate cascade-deletes all `JuryVotes` rows linked to it.

Run `sql/migrate-candidate-publication-and-jury-vote-rules.sql` before running
`sql/seed-voting-history-test-data.sql` or using either application against the
shared database.