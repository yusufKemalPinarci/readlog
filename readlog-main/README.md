# Libris

Okuma yolculuğunu takip etmek için modern bir Flutter uygulaması.

## Özellikler

- 📚 Kitap yönetimi (Okuyacağım, Okuyorum, Okudum)
- ⏱️ Okuma süresi takibi (sesli/sessiz okuma)
- 📝 Okuma notları ve kayıtları
- 📊 İstatistikler ve günlük hedefler
- 👤 Profil yönetimi
- ⚙️ Ayarlar ve özelleştirme
- 💾 Yerel yedekleme (ZIP/JSON dışa/içe aktarma)

## Mimari

- **MVVM Pattern** - Temiz mimari
- **Riverpod** - State management
- **GoRouter** - Navigation
- **Repository Pattern** - Veri kaynağını değiştirmek kolay

## Veri

Tüm veriler cihazda yerel olarak saklanır: `shared_preferences` (JSON) ve
uygulamaya özel dosya dizinleri (kapaklar, ses kayıtları, notlar). Uygulama
verileri ağ üzerinden bir sunucuya göndermez; yedekleme yalnızca kullanıcının
başlattığı dışa/içe aktarma ile yapılır.

## Kurulum

```bash
# Paketleri yükle
flutter pub get

# Projeyi çalıştır
flutter run
```

> Not: Release derlemesi için `android/key.properties` (gerçek bir keystore)
> gerekir; aksi halde release derlemesi bilinçli olarak hata verir.

## Lisans

Bu proje özel bir projedir.
