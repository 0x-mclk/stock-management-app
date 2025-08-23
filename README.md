# Stok Takip Uygulaması

Modern ve kullanıcı dostu Flutter tabanlı stok takip uygulaması.

## 🚀 Özellikler

### ✅ Tamamlanan Özellikler

- **Ana Dashboard**: Genel durum kartları ve hızlı işlemler ✅
- **Modern UI**: Material Design 3 kullanımı ✅
- **Responsive Tasarım**: Mobil cihazlara optimize ✅
- **State Management**: Provider kullanımı ✅
- **Tema Desteği**: Açık/koyu mod ✅
- **Navigation**: Alt navigasyon ile kolay gezinme ✅
- **Splash Screen**: Uygulama başlangıç ekranı ✅
- **Barkod/QR Tarayıcı**: Kamera entegrasyonu ✅
- **Offline Durum**: Bağlantı durumu takibi ✅
- **Bildirim Sistemi**: Push notification altyapısı ✅
- **Çoklu Rapor Ekranları**: Farklı rapor görünümleri ✅
- **Kamera Entegrasyonu**: Ürün fotoğrafı çekme ✅
- **Fiyat Kontrol**: Hızlı ürün fiyat sorgulama ✅
- **Excel Servisi**: Import/Export altyapısı ✅
- **Database Servisi**: Veri yönetimi altyapısı ✅

### 📋 Geliştirilecek Özellikler

#### 1. Ürün Yönetimi

- [x] Temel yapı
- [ ] Ürün ekleme/düzenleme formu
- [ ] Barkod okuyucu entegrasyonu
- [ ] Excel import/export
- [ ] Toplu işlemler
- [ ] Kategori yönetimi

#### 2. Satış Modülü

- [x] Temel yapı
- [ ] Sepet yönetimi
- [ ] Barkod ile ürün ekleme
- [ ] Ödeme seçenekleri
- [ ] Fiş yazdırma
- [ ] İndirim ve iskonto

#### 3. Müşteri Yönetimi

- [x] Temel yapı
- [ ] Müşteri CRUD işlemleri
- [ ] Borç takibi
- [ ] Ödeme geçmişi
- [ ] Müşteri detay sayfası

#### 4. Tedarikçi Yönetimi

- [x] Temel yapı
- [ ] Tedarikçi CRUD işlemleri
- [ ] Alış takibi
- [ ] Borç yönetimi
- [ ] Analiz grafikleri

#### 5. Raporlama

- [x] Temel yapı
- [ ] Satış raporları
- [ ] Stok raporları
- [ ] Finansal raporlar
- [ ] PDF/Excel export

#### 6. Kasa Yönetimi

- [x] Temel yapı
- [ ] Gelir/gider takibi
- [ ] Nakit işlem geçmişi
- [ ] Kasa raporu

#### 7. Ayarlar

- [x] Temel yapı
- [ ] Kullanıcı yönetimi
- [ ] Yedekleme/geri yükleme
- [ ] Bildirim ayarları
- [ ] Tema seçimi

#### 8. İleri Özellikler

- [ ] Offline mod (SQLite)
- [ ] Barkod okuma (Camera)
- [ ] Push bildirimleri
- [ ] Çoklu dil desteği
- [ ] Veri senkronizasyonu

## 🛠️ Teknolojiler

- **Frontend**: Flutter
- **State Management**: Provider
- **Database**: SQLite (SQFlite)
- **UI**: Material Design 3
- **Charts**: FL Chart
- **Fonts**: Google Fonts

## 📱 Ekranlar

1. **Ana Sayfa (Dashboard)** ✅

   - Özet kartlar
   - Hızlı erişim butonları
   - Bildirimler

2. **Ürün Yönetimi** 🔄

   - Ürün listesi
   - Ürün formu
   - Barkod okuma

3. **Satış** 🔄

   - Sepet yönetimi
   - Ödeme işlemleri
   - Fiş yazdırma

4. **Müşteriler** 🔄

   - Müşteri listesi
   - Borç takibi

5. **Tedarikçiler** 🔄

   - Tedarikçi listesi
   - Alış takibi

6. **Raporlar** 🔄

   - Satış analizi
   - Stok durumu

7. **Kasa** 🔄

   - Gelir/gider
   - Nakit takibi

8. **Ayarlar** 🔄
   - Tema ayarları
   - Kullanıcı ayarları

### ✅ **Tamamlanan Ekranlar**

1. **Ana Sayfa (Dashboard)** - Özet kartlar ve hızlı erişim
2. **Ana Ekran (Main Screen)** - Alt navigasyon sistemi
3. **Splash Screen** - Uygulama başlangıç ekranı
4. **Ürün Yönetimi** - Ürün listesi ve yönetimi
5. **Satış Ekranı** - POS sistemi
6. **Müşteriler** - Müşteri yönetimi
7. **Tedarikçiler** - Tedarikçi yönetimi ve detay sayfası
8. **Kasa Yönetimi** - Gelir/gider takibi
9. **Raporlar** - Çoklu rapor ekranları
10. **Ayarlar** - Uygulama ayarları

### 🎯 **Özel Özellik Ekranları**

- **Barkod Tarayıcı** - QR/Barkod okuma
- **Kamera ile Ürün Ekleme** - Fotoğraf çekme
- **Fiyat Kontrol** - Hızlı fiyat sorgulama
- **QR Ürün Analizi** - Ürün detay analizi
- **Basit Raporlar** - Özet rapor görünümü
- **Yeni Raporlar** - Gelişmiş rapor sistemi

## 🚀 Kurulum

### Gereksinimler

- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)

### Kurulum Adımları

1. Repoyu klonlayın:
   \`\`\`bash
   git clone https://github.com/0x-mclk/stock-management-app.git
   cd stock-management-app
   \`\`\`

2. Bağımlılıkları yükleyin:
   \`\`\`bash
   flutter pub get
   \`\`\`

3. Uygulamayı çalıştırın:
   \`\`\`bash
   flutter run
   \`\`\`

## 📦 Paket Bağımlılıkları

### Temel Paketler

- `flutter`
- `provider` - State management
- `sqflite` - Local database
- `path_provider` - File paths

### UI Paketleri

- `google_fonts` - Font ailesi
- `flutter_animate` - Animasyonlar
- `cupertino_icons` - iOS iconları

### Özellik Paketleri

- `qr_code_scanner` - Barkod okuma
- `camera` - Kamera erişimi
- `excel` - Excel işlemleri
- `pdf` - PDF oluşturma
- `fl_chart` - Grafik çizimi

### Utility Paketler

- `intl` - Tarih/saat formatı
- `uuid` - Unique ID oluşturma
- `shared_preferences` - Local storage
- `connectivity_plus` - İnternet durumu

## 🎨 Tasarım Prensipleri

- **Material Design 3**: Modern ve tutarlı UI
- **Responsive**: Tüm ekran boyutlarına uyumlu
- **Accessibility**: Erişilebilirlik odaklı
- **Performance**: Optimize edilmiş performans
- **User Experience**: Kullanıcı dostu arayüz

## 📝 Geliştirme Notları

### Mevcut Durum

- ✅ **Temel uygulama yapısı tamamlandı**
- ✅ **Provider state management yapısı kuruldu**
- ✅ **Ana navigation sistemi çalışıyor**
- ✅ **20+ ekran geliştirildi**
- ✅ **Splash screen ve main screen hazır**
- ✅ **Dashboard ekranı hazır**
- ✅ **Barkod tarayıcı entegrasyonu**
- ✅ **Kamera ile ürün ekleme**
- ✅ **Çoklu rapor ekranları**
- ✅ **Offline durum yönetimi**
- ✅ **Tema sistemi (açık/koyu mod)**
- ✅ **Bildirim sistemi altyapısı**

### Sonraki Adımlar

1. ✅ ~~Ürün yönetimi ekranını tamamla~~ (Tamamlandı)
2. 🔄 Database operasyonlarını implement et
3. 🔄 Barkod okuma özelliğini optimize et
4. 🔄 Satış modülünü geliştir
5. 🔄 Raporlama sistemi kur
6. 🔄 Excel import/export özelliği
7. 🔄 Offline mod (SQLite) entegrasyonu

### Kod Yapısı

```
lib/
├── main.dart                          # Ana uygulama başlangıcı
├── models/                            # Veri modelleri
│   ├── product.dart                   # Ürün modeli
│   ├── customer.dart                  # Müşteri modeli
│   ├── supplier.dart                  # Tedarikçi modeli
│   ├── sale.dart                      # Satış modeli
│   └── cash_transaction.dart          # Kasa işlem modeli
├── providers/                         # State management
│   ├── app_provider.dart              # Genel uygulama durumu
│   ├── theme_provider.dart            # Tema yönetimi
│   ├── product_provider.dart          # Ürün state management
│   ├── customer_provider.dart         # Müşteri state management
│   ├── supplier_provider.dart         # Tedarikçi state management
│   ├── sales_provider.dart            # Satış state management
│   ├── cash_provider.dart             # Kasa state management
│   └── notification_provider.dart     # Bildirim yönetimi
├── screens/                           # UI ekranları (20+ ekran)
│   ├── main_screen.dart               # Ana container ekranı
│   ├── splash_screen.dart             # Başlangıç ekranı
│   ├── dashboard_screen.dart          # Dashboard
│   ├── products_screen.dart           # Ürün yönetimi
│   ├── sales_screen.dart              # Satış POS ekranı
│   ├── customers_screen.dart          # Müşteri yönetimi
│   ├── suppliers_screen.dart          # Tedarikçi listesi
│   ├── cash_screen.dart               # Kasa yönetimi
│   ├── reports_screen.dart            # Raporlar
│   ├── barcode_scanner_screen.dart    # Barkod tarayıcı
│   └── ... (diğer özel ekranlar)
├── services/                          # İş mantığı servisleri
│   ├── database_service.dart          # Veritabanı işlemleri
│   ├── data_service.dart              # Veri yönetimi
│   ├── excel_service.dart             # Excel import/export
│   ├── notification_service.dart      # Bildirim servisi
│   ├── connectivity_service.dart      # İnternet bağlantısı
│   └── offline_service.dart           # Offline mod
├── utils/                             # Yardımcı fonksiyonlar
│   └── currency_formatter.dart        # Para formatı
└── widgets/                           # Tekrar kullanılabilir bileşenler
    └── offline_status_widget.dart     # Offline durum widget'ı
```

## 🤝 Katkıda Bulunma

Bu proje aktif geliştirme aşamasındadır. Katkılarınızı bekliyoruz!

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

---

**Not**: Bu uygulama, modern stok takip ihtiyaçlarını karşılamak için geliştirilmektedir. Tüm özellikler aşamalı olarak eklenmektedir.
