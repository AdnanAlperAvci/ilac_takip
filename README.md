# İlaç Takip

İlaç Takip, günlük ilaç rutinlerini takip etmek için hazırlanmış Flutter tabanlı bir mobil uygulamadır. Uygulama Android tarafında belirlenen saatten sonra telefon kilidi her açıldığında, o gün alınmamış ilaç varsa bildirim gönderecek şekilde tasarlanmıştır.

## Uygulamanın Fonksiyonları

İlaç Takip, kullanıcının düzenli kullandığı ilaçları telefonda yerel olarak takip eder. Ana ekranda günün ilaçları, tamamlanma durumu, kilit açma bildirimi saati ve rutin listesi birlikte gösterilir.

- İlaç rutini ekleme, düzenleme, aktif/pasif yapma ve silme.
- Günde bir, iki günde bir veya haftanın belirli günleri için rutin tanımlama.
- İki günde bir kullanılan ilaçlarda rutinin bugün mü yarın mı başlayacağını seçme.
- İlaç saatini isteğe bağlı tutma; saat girilmezse rutin yine takvim ve bildirim hesabına dahil edilir.
- Dozu iki ondalıklı sayısal değer olarak kaydetme.
- Kutudaki adet bilgisini girme, barkoddan otomatik doldurma ve kutu bitince rutini takvim hesabından düşürme.
- Bugün alınması gereken ilaçları listeleme ve her ilacı alındı olarak işaretleme.
- Haftalık takvim gösterme; takvime dokununca aylık görünüme geçme.
- Aylık takvimde önceki ve sonraki aylar arasında oklarla gezinme.
- Takvim günlerinde o gün kaç rutin varsa o kadar kapsül ikonu gösterme.
- Belirlenen saatten sonra, ilaç alındı işaretlenene kadar her telefon kilidi açılışında bildirim gönderme.
- Uygulama açıldığında Android bildirim iznini otomatik isteme.
- Kilit açma bildirimlerini kullanıcı tarafından açıp kapatabilme.
- İlaç kutusundaki QR veya DataMatrix kodunu okuyarak barkoddan ilaç adını ve kutu adedini otomatik doldurma.
- Barkod aramasını cihaz içinde, APK'ya eklenen yerel TİTCK ilaç listesiyle yapma.
- Uygulama içinde gizlilik ve tıbbi beyan ekranı gösterme.
- Türkçe arayüz, Türkçe takvim günleri ve Türkçe açıklama metinleri kullanma.

## Kullanılan Teknolojiler

- Flutter: Ana mobil arayüz, form ekranları, takvim görünümü ve kullanıcı etkileşimleri için kullanılır.
- Dart: İlaç rutini modeli, tarih/rutin hesapları, doz doğrulama, barkod ayrıştırma ve yerel ilaç listesi okuma işlemlerini yürütür.
- Android Kotlin: Kilit açma takibi, native bildirimler, foreground service ve Android izin akışını yönetir.
- `mobile_scanner`: QR ve DataMatrix kodlarını telefon kamerasıyla okumak için kullanılır.
- Android `SharedPreferences`: İlaç rutinlerini, alınan günleri ve bildirim saatini cihazda yerel olarak saklar.
- Android `BroadcastReceiver`: Telefon kilidi açıldığında Android olaylarını yakalamak için kullanılır.
- Android foreground service: Uygulama kapalıyken de kilit açma takibinin çalışmasına yardımcı olur.
- Yerel JSON asset: TİTCK kaynaklı barkod, ilaç adı ve kutu adedi verisini APK içinde taşır.
- Python yardımcı scripti: Resmi TİTCK Excel listesinden `assets/medicine_barcodes.json` dosyasını üretmek için kullanılır.

## Kurulum

Bağımlılıkları indirmek için:

```bash
flutter pub get
```

Android cihazda çalıştırmak için:

```bash
flutter run
```

Play Store için release paketi hazırlarken uygulama imzalama bilgileri `android/key.properties` dosyasından okunur. Bu dosya ve keystore dosyaları güvenlik için Git'e eklenmez.

Örnek `android/key.properties` içeriği:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=app/upload-keystore.jks
```

Release App Bundle üretmek için:

```bash
flutter build appbundle --release
```

## Android İzinleri

Uygulama Android tarafında şu izinleri kullanır:

- Kamera izni: İlaç kutusundaki QR veya DataMatrix kodunu okumak için.
- Bildirim izni: Android 13 ve üzeri cihazlarda ilaç hatırlatma bildirimi göstermek için. Uygulama açıldığında otomatik istenir.
- Foreground service izni: Kilit açma bildirimi açıkken arka plan kilit açma takibini çalıştırmak için.
- Boot completed izni: Telefon yeniden başladığında kullanıcı kapatmadıysa kilit açma takibini tekrar başlatmak için.

## Gizlilik ve Tıbbi Beyan

İlaç Takip tıbbi tavsiye vermez, ilaç önermez, doz belirlemez, reçete yerine geçmez ve tedavi kararı vermez. Uygulama yalnızca kullanıcının kendi girdiği ilaç rutinlerini takip etmesine ve hatırlamasına yardımcı olur.

İlaç adı, doz, kutu adedi, rutin bilgisi ve alındı kayıtları cihazdaki yerel depolamada tutulur. Bu bilgiler uygulama tarafından bir sunucuya gönderilmez. Kamera yalnızca QR veya DataMatrix kodunu okumak için kullanılır. Barkod eşleştirme APK içindeki yerel TİTCK ilaç listesiyle yapılır.

## Play Store Yayın Hazırlığı

- Paket adı `com.adnanalperavci.ilactakip` olarak örnek paket adından ayrılmıştır.
- Debug sürümü gerçek uygulamanın üzerine yazmasın diye `.test` paket ekiyle kurulur.
- Release imzası için `android/key.properties` desteklenir; gerçek keystore bilgileri repoya eklenmez.
- Play Console'da Health apps declaration, Data safety ve Foreground service declaration alanları doldurulmalıdır.
- Google Play'in güncel hedef API şartı release almadan önce Android SDK ve Flutter sürümüyle doğrulanmalıdır.
- Herkese açık bir gizlilik politikası URL'si Play Console'a eklenmelidir.

## Barkoddan İlaç Adı Alma

Uygulama, ilaç kutusundan okunan barkodu APK içine eklenen `assets/medicine_barcodes.json` dosyasında arar ve eşleşen ilaç adını forma yazar. Kutu adedi bilgisi TİTCK listesinde varsa doğrudan, yoksa ilaç adındaki paket bilgisinden otomatik doldurulur. Barkod yerel listede bulunamazsa ilaç adı alanına `Barkod ...` gibi geçici bir metin yazılmaz; kullanıcıya hata mesajı gösterilir.

Tam barkod listesini güncellemek için resmi TİTCK SKRS E-Reçete İlaç ve Diğer Farmasötik Ürünler Listesi kaynak alınır. Script, TİTCK sayfasındaki en güncel Excel dosyasını indirip yerel asset'i yeniden oluşturabilir:

```bash
python scripts/build_titck_medicine_barcodes.py
```

Elinizde indirilmiş resmi TİTCK Excel dosyası varsa onu doğrudan da kullanabilirsiniz:

```bash
python scripts/build_titck_medicine_barcodes.py --source path/to/titck.xlsx
```

Bu işlem yalnızca uygulamayı hazırlarken gerekir. Kullanıcı telefonunda IP girmez, ayrı sunucu çalıştırmaz ve barkod arama cihaz içinde yapılır.

## Notlar

Kilit açma bildirimi Android'in `USER_PRESENT` olayıyla çalışır. Uygulama, belirlenen saatten sonra telefon kilidi açıldığında o gün alınmamış ilaçları kontrol eder ve ilaç alındı işaretlenene kadar her kilit açmada bildirim gönderir.

Android, foreground service kullanan uygulamaların servis çalışırken sistem bildirimi göstermesini zorunlu tutar. Bu nedenle kilit açma takibi açıkken sessiz ve düşük öncelikli bir "İlaç Takip" servis bildirimi oluşabilir; asıl ilaç hatırlatması yalnızca alınmamış ilaç varsa gösterilir.

QR içerikleri düz metin, JSON, URL sorgu parametresi veya etiketli metin formatında olabilir. DataMatrix içinde GS1 `(01)` barkodu varsa ilaç adı yerel TİTCK listesi üzerinden bulunur. Örneğin:

```text
{"ilacAdi":"Parol"}
```

```text
https://ornek.com/ilac?ilac_adi=Parol
```

```text
İlaç adı: Parol
```
