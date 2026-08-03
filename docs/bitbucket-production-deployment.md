# Bitbucket Üretim Taşıma Rehberi

## Kritik karar

Yerel `AfifeAdmin` veritabanının MDF/backup dosyasını üretimdeki veritabanının üzerine
kopyalamayın. Bu, şirket verisini kaybettirir. Doğru yöntem eski üretim DB'sini yerinde,
EF migration ile yeni şemaya genişletmek ve ardından yeni uygulama artefaktını dağıtmaktır.

## Bir defalık hazırlık

1. Bu branch'i Bitbucket deposuna aktarın ve şirket otomasyonunun hedef branch'i yapın.
2. Windows self-hosted runner etiketlerini `bitbucket-pipelines.yml` içindeki
   `self.hosted`, `windows`, `production` değerleriyle eşleştirin.
3. Bitbucket Deployment/Repository Variables içine güvenli değişkenleri ekleyin:
   `AFIFE_SQL_SERVER`, `AFIFE_SQL_DATABASE`, isteğe bağlı `AFIFE_SQL_USER` ve
   secured `AFIFE_SQL_PASSWORD`.
4. `AFIFE_BACKUP_CONFIRMED` değişkenini normalde `NO` tutun. Yalnızca aynı gün alınan
   full backup ayrı bir SQL Server örneğine restore edilip doğrulandıktan sonra `YES` yapın.
5. Production uygulama ayarında `DatabaseMigration__ApplyOnStartup=false` kullanın.
   Pipeline DB'yi önce yükseltir; uygulama yine pending migration/schema drift varsa açılmaz.

## Prova

1. Üretim DB'sinin copy-only full backup'ını alın.
2. Backup'ı ayrı bir staging SQL Server'a restore edin.
3. Şema metni veya yapay test yerine gerçek restore üzerinde idempotent artefaktı çalıştırın.
4. `pre-migration-row-counts.txt` ve `post-migration-row-counts.txt` çıktılarını karşılaştırın.
5. Form kayıtlarının hem `dbo.Form` içinde GUID + `LegacyId` ile bulunduğunu hem
   `dbo.FormLegacy_PreEf` içinde eski kolonlarıyla korunduğunu doğrulayın.
6. Login, başvurular, oyunlar, adaylar, oylar, bilet ücretleri, sıralamalar ve export
   smoke testlerini staging uygulamasında çalıştırın.

## Üretim sırası

1. Bakım penceresi açın ve eski uygulamadaki yazma trafiğini durdurun.
2. Son full backup'ı alın; başka instance'a restore ederek okunabildiğini doğrulayın.
3. `AFIFE_BACKUP_CONFIRMED=YES` yapın.
4. Bitbucket build adımının yeşil olduğunu ve `artifacts/deploy/YKBAfife-idempotent.sql`
   ürettiğini kontrol edin.
5. Manual `Production database gate` adımını çalıştırın. Hata olursa EF transaction geri
   alınır ve uygulama rollout'una geçilmez.
6. Row-count çıktılarını inceleyin. Eski iş tablolarında azalma olmamalıdır; yeni audit,
   season, ranking ve ilişki tabloları nedeniyle toplam tablo/satır sayısı artabilir.
7. Şirketin mevcut otomasyonu ile `artifacts/publish` klasörünü yeni slot/dizine dağıtın.
8. Connection string ve production environment değişkenlerini bağlayın; uygulamayı başlatın.
9. Health/startup logunda `Database schema validation completed successfully` mesajını görün.
10. Smoke testlerden sonra trafiği yeni sürüme alın ve `AFIFE_BACKUP_CONFIRMED` değerini `NO` yapın.

## Geri dönüş

Migration `Down` işlemleri veri taşıyan kolon/tablo silmez. Uygulama rollback gerekiyorsa
önce eski uygulamanın genişletilmiş şemayla uyumluluğunu doğrulayın. DB rollback zorunluysa
üretim DB'sini yerinde parçalamayın: doğrulanmış full backup'ı yeni bir DB adına restore edin,
connection string'i kontrollü biçimde o DB'ye çevirin ve olay kayıtlarını saklayın.

## Pipeline notları

Build adımı destructive migration API/SQL taraması, Release build, EF snapshot drift kontrolü,
idempotent migration SQL üretimi ve publish yapar. Production adımı yakın tarihli full backup'ı
`msdb` üzerinden doğrular. Şirket runner hesabının hedef DB ve `msdb.dbo.backupset` için gerekli
okuma yetkisi, hedef DB için migration DDL yetkisi ve `sqlcmd` aracı olmalıdır.
