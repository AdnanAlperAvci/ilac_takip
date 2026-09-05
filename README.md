# İlaç Takip

İlaç Takip, düzenli kullanılan ilaçları telefonda takip etmek için hazırlanmış Flutter tabanlı bir Android uygulamasıdır. Kullanıcı kendi ilaç rutinlerini ekler, günlük alım durumunu işaretler ve belirlediği saatten sonra telefon kilidi açıldığında alınmamış ilaçlar için bildirim alır.

Uygulama tıbbi tavsiye vermez, ilaç önermez ve doz belirlemez. Yalnızca kullanıcının kendi girdiği ilaçları hatırlamasına ve takip etmesine yardımcı olur.

## Özellikler

- İlaç ekleme, düzenleme, aktif/pasif yapma ve silme.
- Günde bir, iki günde bir veya haftanın belirli günleri için rutin oluşturma.
- İki günde bir kullanılan ilaçlarda rutinin bugün veya yarın başlamasını seçme.
- İlaç saatini isteğe bağlı girme.
- Doz bilgisini iki ondalıklı sayısal değer olarak kaydetme.
- Kutudaki adet bilgisini girme ve kutu bitince rutini takvim hesabından düşürme.
- Bugün alınacak ilaçları listeleme ve alındı olarak işaretleme.
- Haftalık takvim ve dokununca açılan aylık takvim görünümü.
- Takvim günlerinde o günkü rutin sayısı kadar kapsül ikonu gösterme.
- Belirlenen saatten sonra, ilaç alındı işaretlenene kadar her kilit açmada bildirim gönderme.
- Kilit açma bildirimlerini kullanıcı tarafından açıp kapatma.
- QR veya DataMatrix kodu okuyarak barkoddan ilaç adını ve kutu adedini otomatik doldurma.
- Türkçe arayüz ve Türkçe takvim metinleri.

## Barkod ve TİTCK Listesi

İlaç kutusundaki QR veya DataMatrix kodundan barkod okunur. Uygulama bu barkodu APK içinde bulunan `assets/medicine_barcodes.json` dosyasında arar ve eşleşen ilaç adını forma yazar. Kutu adedi bilgisi listede varsa otomatik doldurulur; kullanıcı isterse elle değiştirebilir.

Barkod eşleştirme için TİTCK tarafından yayımlanan **SKRS E-Reçete İlaç ve Diğer Farmasötik Ürünler Listesi** temel alınır:

[TİTCK SKRS E-Reçete İlaç ve Diğer Farmasötik Ürünler Listesi](https://www.titck.gov.tr/dinamikmodul/43)

Listeyi güncellemek için:

```bash
python scripts/build_titck_medicine_barcodes.py
```

Elinizde indirilmiş bir TİTCK Excel dosyası varsa:

```bash
python scripts/build_titck_medicine_barcodes.py --source path/to/titck.xlsx
```

Bu işlem yalnızca uygulama hazırlanırken gerekir. Kullanıcı telefonda IP girmez, ayrı sunucu çalıştırmaz ve barkod arama cihaz içinde yapılır.

## Kullanılan Teknolojiler

- Flutter ve Dart: Mobil arayüz, rutin formları, takvim ve ilaç takip mantığı.
- Android Kotlin: Kilit açma takibi, bildirimler, foreground service ve Android izin akışı.
- `mobile_scanner`: QR ve DataMatrix kod okuma.
- Android `SharedPreferences`: Rutinleri, alınan günleri ve bildirim ayarlarını yerel olarak saklama.
- Yerel JSON asset: TİTCK kaynaklı barkod ve ilaç bilgilerini uygulama içinde kullanma.
- Python: TİTCK Excel listesinden yerel barkod JSON dosyasını üretme.

## Kurulum

Bağımlılıkları indirmek için:

```bash
flutter pub get
```

Android cihazda çalıştırmak için:

```bash
flutter run
```

Debug sürümü gerçek uygulamanın üzerine yazmaması için ayrı paket ekiyle kurulur.

Release App Bundle üretmeden önce `android/key.properties.example` dosyasını `android/key.properties` olarak kopyalayıp gerçek keystore şifreleriyle doldurun. `android/key.properties` ve keystore dosyaları Git'e eklenmez.

Play Store'a yüklenecek dosyayı üretmek için:

```bash
flutter build appbundle --release
```

## İzinler

- Kamera izni: QR veya DataMatrix kodunu okumak için kullanılır.
- Bildirim izni: İlaç hatırlatma bildirimi göstermek için kullanılır.
- Arka plan servis izni: Kilit açma bildirimi açıkken kilit açma takibini sürdürebilmek için kullanılır.

İlaç adı, doz, kutu adedi, rutin bilgisi ve alındı kayıtları cihazdaki yerel depolamada tutulur. Bu bilgiler uygulama tarafından bir sunucuya gönderilmez.

Gizlilik politikası: [İlaç Takip Gizlilik Politikası](https://adnanalperavci.github.io/ilac_takip/privacy-policy.html)
