# Admin Write Action Inventory

This inventory is covered centrally by `AdminLogs`; controllers must not add
operation-specific `UsersLog` entries for these business operations.
Every listed mutation endpoint is marked with `[AdminMutationAudit]` so only its
failed attempts receive an additional `FailedAction` record.

| Area | Route/action | Data operation |
| --- | --- | --- |
| Jury | `POST /juriler/{id}/sil` | User soft delete and dependent updates |
| Jury | `POST /juriler/{id}/duzenle` | User/photo update, optional image insert/soft delete |
| Jury | `POST /juri-ekle` | User and optional image insert |
| Admin | `POST /admin-yonetimi/{id}/status` | `Users.IsActive` toggle |
| Admin | `POST /admin-yonetimi/ekle` | User insert |
| Admin | `POST /admin-yonetimi/{id}/duzenle` | User update |
| Admin | `POST /admin-yonetimi/{id}/sil` | User soft delete and dependent updates |
| Play | `POST /oyunlar/{id}/juri-oylama-status` | Jury-voting status toggle |
| Play | `POST /oyunlar/{id}/kunye-giris-status` | Kunye status toggle |
| Play | `POST /oyunlar/ekle` | Play and jury-assignment inserts |
| Play | `POST /oyunlar/{slug}/duzenle` | Play and jury-assignment updates |
| Play | `POST /oyunlar/{id}/sil` | Admin-play and related-row soft deletes |
| Candidate | `POST /oyunlar/{slug}/aday-ekle` | Candidate/image insert and replacement update |
| Candidate | `POST /adaylar/{id}/duzenle` | Candidate/role-group/photo updates |
| Candidate | `POST /adaylar/{id}/status` | Candidate activity toggle and vote side effects |
| Candidate | `POST /adaylar/{id}/sil` | Candidate and vote soft deletes |
| Voting | `POST /oylama-gecmisi/oylamayi-sifirla` | Vote soft delete |
| Ticket fee | `POST /bilet-satislari/{id}/duzenle` | Ticket-fee update |
| Blacklist | `POST /blacklists/ekle` | Blacklist insert |
| Blacklist | `POST /blacklists/{id}/sil` | Blacklist soft delete |

Page visits, GET/HEAD requests, successful exports, and successful read-only table
POST requests are not logged. A successful write is represented only by its SQL
data-change logs; a failed write is represented by one `FailedAction` entry with
its attempted field values and failure details.
