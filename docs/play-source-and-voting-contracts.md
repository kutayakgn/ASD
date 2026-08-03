# Oyun Kaynak ve Oylama Sozlesmesi

AfifeAdmin ve Kunye Giris Sistemi ayni veritabanini kullanir. `Plays.RecordType`
alani bir durum alani degil, oyunun hangi platformdan olusturuldugunu belirleyen
degismez kaynak bilgisidir.

Bir oyun kaydi olusturulduktan sonra `RecordType` degeri hicbir kosulda
degistirilemez. Kaynak duzeltmesi gerekiyorsa mevcut kaydi donusturmek yerine,
veri sahipligi ve iliskileri ayrica degerlendirilerek yeni bir kayit akisi
tasarlanmalidir.

## RecordType degerleri

| RecordType | Kaynak |
| --- | --- |
| `0` | Kunye Giris Sistemi |
| `1` | AfifeAdmin |

Kunye Giris Sistemi su anda basvuru formunu `Form` tablosuna kaydeder. Diger
proje guncellendiginde ayni islem ayrica `Plays`, `PlayAwardCategories` ve ilgili
normalize tablolara `RecordType = 0` ile kayit olusturmalidir.

## Statu alanlari

`KunyeGirisStatus`, `RecordType` ile ayni anlami tasimaz. Bu alan, Kunye Giris
Sistemi projesindeki ilgili oyun listesinde kaydin gorunur olup olmadigini belirler.

`JuriOylamaStatus`, oyunun juri oylama sitesinde oylamaya acik olup olmadigini
belirler.

Bu iki toggle yalnizca `RecordType = 0` oyunlarda degistirilebilir. `RecordType = 1`
oyunlarda her iki deger de daima `0` olmali ve arayuzde duzenlenemez olmalidir.

## Iliski matrisi

| Iliskili tablo/islem | RecordType 0 | RecordType 1 |
| --- | --- | --- |
| `PlayAwardCategories` | Izinli | Yasak |
| `JuryVotes` | Izinli | Yasak |
| `JuryGameTicketFees` | Izinli | Izinli |
| `JuryAssignedPlays` | Izinli | Izinli |
| `Blacklist` | Izinli | Yasak |

Yalnizca Kunye Giris Sistemi kaynakli oyunlarin adaylari, odul kategorileri ve
juri oylari olabilir. Admin panelinden olusturulan oyunlar oylamaya acilamaz;
juriler bu oyunlar icin yalnizca bilet ucreti kaydi olusturabilir.

`JuryAssignedPlays`, her iki kaynak turunde de juri-oyun atamasini tutabilir.
Admin kaynakli oyunlarda bu atama oy kullanma yetkisi olusturmaz.

## Uygulama ve veritabani kurallari

- `RecordType = 0` oyunlar soft-delete edilemez ve `IsPublished` degerleri
  her zaman `1` olmalidir. Yalnizca `RecordType = 1` oyunlar soft-delete edilebilir.
- Aday ve oylama ekranlari yalnizca `RecordType = 0` oyunlari listelemelidir.
- Bilet ucreti akislari her iki `RecordType` degerini desteklemelidir.
- `RecordType = 1` bir oyun icin `PlayAwardCategories`, `JuryVotes` veya
  `Blacklist` kaydi olusturulmamalidir.
- Aday veya blacklist kaydi bulunan bir oyun, iliskiler kaldirilmadan
  `RecordType = 1` yapilamaz.
- Kunye oyununun statu toggle guncellemesi `RecordType` degerini degistirmemelidir.
- Statu toggle guncellemesi veritabanina hemen yazilir; ancak acik oyunlar tablosu
  otomatik yenilenmez. Boylece yeni kayit etiketi ve satir konumu, kullanici arama,
  siralama, filtreleme, pagination veya sayfa navigasyonu yapana kadar korunur.
- the versioned EF migration resources in `Migrations/Scripts`, mevcut `Plays` kayitlarinin
  `RecordType` degerinin SQL veya baska bir uygulama tarafindan degistirilmesini
  engeller.
- the versioned EF migration resources in `Migrations/Scripts`, RecordType trigger'ini yalnizca gercek
  `0 -> 1` degisiminde calisacak sekilde kurar.
- the versioned EF migration resources in `Migrations/Scripts`, yasak iliskileri temizler ve
  tekrar olusmalarini trigger'larla engeller.
- the versioned EF migration resources in `Migrations/Scripts`, Admin kaynakli oyunlarin iki statusunu
  `0` olarak ve `StatusCode` degerini `1` disinda tutar.
## Form kaynakli Kunye oyunlari

Kunye Giris projesindeki `Form` kayitlarinin oyun ve bagli kayit yasam dongusu
`docs/form-kunye-play-lifecycle-contract.md` dosyasinda tanimlidir. Form kaynakli
oyunlar `Plays.SourceFormId` ile birebir baglanir. Form pasif oldugunda Kunye
oyununun `IsPublished` degeri degismez; `Plays.IsActive = 0` olur ve bagli
aday/oy/bilet/atama/blacklist kayitlari snapshot ile soft-delete edilir.