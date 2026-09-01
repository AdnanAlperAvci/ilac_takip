# İlaç Takip

İlaç Takip, günlük ilaç rutinlerini takip etmek için hazırlanmış Flutter tabanlı bir mobil uygulamadır. Uygulama Android tarafında belirlenen saatten sonra telefon kilidi ilk açıldığında, o gün alınmamış ilaç varsa bildirim gönderecek şekilde tasarlanmıştır.

## Özellikler

- İlaç rutini ekleme, düzenleme ve silme
- Günde bir, iki günde bir veya haftanın belirli günleri için rutin tanımlama
- Doz bilgisini iki ondalıklı sayısal formatta kaydetme
- Bugün alınacak ilaçları listeleme
- İlaçları alındı olarak işaretleme
- Belirlenen saatten sonra ilk kilit açmada Android bildirimi gönderme
- İlaç kutusundaki QR kodu okuyarak ilaç adını otomatik doldurma
- Türkçe tarih seçici ve Türkçe arayüz metinleri

## Kullanılan Teknolojiler

- Flutter
- Dart
- Android Kotlin
- `mobile_scanner` ile QR okuma
- Android `SharedPreferences` ile yerel veri saklama
- Android `BroadcastReceiver` ile kilit açma olayını yakalama

## Kurulum

Bağımlılıkları indirmek için:

```bash
flutter pub get
```

Android cihazda çalıştırmak için:

```bash
flutter run
```

## Android İzinleri

Uygulama Android tarafında şu izinleri kullanır:

- Kamera izni: İlaç kutusundaki QR kodu okumak için.
- Bildirim izni: Android 13 ve üzeri cihazlarda ilaç hatırlatma bildirimi göstermek için.

## Notlar

Kilit açma bildirimi Android'in `USER_PRESENT` olayıyla çalışır. Uygulama, belirlenen saatten sonra gün içinde ilk kez telefon kilidi açıldığında o gün alınmamış ilaçları kontrol eder ve uygunsa bildirim gönderir.

QR içerikleri düz metin, JSON, URL sorgu parametresi veya etiketli metin formatında olabilir. Örneğin:

```text
{"ilacAdi":"Parol"}
```

```text
https://ornek.com/ilac?ilac_adi=Parol
```

```text
İlaç adı: Parol
```
