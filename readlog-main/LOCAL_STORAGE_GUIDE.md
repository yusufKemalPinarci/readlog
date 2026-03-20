# Local Storage Rehberi

## 📦 Veri Depolama Yapısı

Uygulama tüm verileri **local storage**'da tutar. Firebase veya başka bir cloud servis kullanılmaz.

### Veri Depolama Yöntemleri

#### 1. SharedPreferences
- **Kullanım**: Kitaplar, okuma kayıtları, tema ayarları, bildirim ayarları
- **Konum**: `lib/shared/services/local_storage_service.dart`
- **Veriler**:
  - Kitaplar (`books_data`)
  - Okuma kayıtları (`reading_logs_data`)
  - Tema modu (`theme_mode`)
  - İlk açılış durumu (`is_first_launch`)

#### 2. Application Documents Directory
- **Kullanım**: Dosyalar (resimler, ses kayıtları, notlar)
- **Konum**: `getApplicationDocumentsDirectory()`
- **Dizinler**:
  - `book_covers/` - Kitap kapakları
  - `notes/` - Metin notları
  - `recordings/` - Ses kayıtları
  - `profile_images/` - Profil resimleri

#### 3. File Storage Services
- **ImageStorageService**: Kitap kapakları
- **NoteStorageService**: Metin notları
- **ProfileImageStorageService**: Profil resimleri
- **AudioRecordingService**: Ses kayıtları

## 🔄 Veri Yönetimi

### Export/Import
- **Export**: Tüm veriler JSON dosyası olarak export edilir
- **Import**: JSON dosyasından veriler import edilir (mevcut verilerle birleştirilir)
- **Konum**: `lib/shared/services/data_backup_service.dart`

### Veri Temizleme
- **Logout**: `LocalStorageService.clearAll()` tüm verileri temizler
- **Manuel Silme**: Her özellik için ayrı silme metodları var

## 🛡️ Güvenlik

### Mevcut Durum
- ✅ Uygulama özel dizin kullanılıyor (diğer uygulamalar erişemez)
- ✅ Dosya yolları doğrulanıyor
- ✅ Hata yönetimi mevcut

### Öneriler
- ⚠️ **Şifreleme**: Hassas veriler için şifreleme eklenebilir
- ⚠️ **Yedekleme**: Otomatik yedekleme mekanizması eklenebilir
- ⚠️ **Veri Temizleme**: Eski verileri otomatik temizleme eklenebilir

## 📊 Veri Yapısı

### Books JSON Format
```json
{
  "id": "string",
  "title": "string",
  "author": "string",
  "totalPages": number,
  "currentPage": number,
  "shelf": "toRead" | "reading" | "read",
  "totalMinutes": number,
  "finalReadingTimeMinutes": number,
  "coverImagePath": "string?",
  "review": "string?",
  "rating": number?,
  "order": number
}
```

### Reading Logs JSON Format
```json
{
  "id": "string",
  "bookId": "string",
  "date": "ISO8601 string",
  "minutes": number,
  "pageAtEnd": number,
  "note": "string?",
  "audioFilePath": "string?",
  "noteFilePath": "string?",
  "title": "string?"
}
```

## 🔧 Servisler

### LocalStorageService
- `saveBooks()` - Kitapları kaydet
- `loadBooks()` - Kitapları yükle
- `saveReadingLogs()` - Okuma kayıtlarını kaydet
- `loadReadingLogs()` - Okuma kayıtlarını yükle
- `clearAll()` - Tüm verileri temizle

### DataBackupService
- `exportData()` - Verileri JSON olarak export et
- `importData()` - JSON dosyasından verileri import et

### File Storage Services
- Her servis kendi dizinini yönetir
- Dosya yolları otomatik oluşturulur
- Hata durumlarında güvenli fallback'ler var

## 📱 Cihazlar Arası Veri Aktarımı

### Export/Import Kullanımı
1. **Export**: Ayarlar → "Verileri Dışa Aktar"
2. Dosyayı kaydet (Drive, e-posta, vb.)
3. **Import**: Başka cihazda Ayarlar → "Verileri İçe Aktar"
4. Dosyayı seç
5. Veriler mevcut verilerle birleştirilir

### Notlar
- Export edilen dosya tüm verileri içerir
- Import sırasında duplicate kontrolü yapılır (aynı ID'ye sahip kayıtlar eklenmez)
- Mevcut veriler korunur, sadece yeni veriler eklenir

## 🚀 Performans

### Optimizasyonlar
- ✅ Async file operations
- ✅ Lazy loading (ihtiyaç duyulduğunda yükleme)
- ✅ Error handling (try-catch blokları)
- ✅ File existence checks

### Öneriler
- ⚠️ **Cache**: Sık kullanılan veriler için cache mekanizması
- ⚠️ **Batch Operations**: Toplu işlemler için batch API'ler
- ⚠️ **Compression**: Büyük dosyalar için sıkıştırma

## 🔄 Background Tasks

### WorkManager
- Local storage için background görevleri yapılabilir
- Veri temizleme, optimizasyon, yedekleme kontrolü
- Network gerektirmez (local storage için)

## 📝 Notlar

- Tüm veriler cihazda saklanır
- Cihaz değiştirildiğinde export/import kullanılmalı
- Veri kaybı riski: Cihaz formatlanırsa veya uygulama silinirse veriler kaybolur
- Yedekleme: Düzenli olarak export yapılması önerilir
