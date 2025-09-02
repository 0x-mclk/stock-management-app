🎯 KOMPLE İŞ AKIŞI - Davetiye + Kayıt Sistemi:
📋 ADIM 1: Davet Gönderme (Mevcut - Çalışıyor ✅) 1. Mağaza sahibi → Takım Yönetimi'ne gider 2. Email girer → yeni@kullanici.com 3. Davet Gönder butonuna basar 4. Firebase'e kaydedilir:
store_invitations/{id}: {
email: "yeni@kullanici.com",
status: "invited",
storeId: "store_xyz",
role: "staff"
} 5. Email gönderilir: "Davet edildiniz" mesajı
📋 ADIM 2: Admin Onayı (Mevcut - Çalışıyor ✅) 1. Admin Firebase Console'a gider 2. Daveti onaylar: status: "invited" → status: "accepted"
📋 ADIM 3: Kullanıcı Kayıt Olma (YENİ - İmplement Edilecek 🔧)
A) İki Tür Kullanıcı Uygulamaya Gelir:
👤 TİP 1: Davetli Kullanıcı
• Davet maili almış
• Uygulamayı indirmiş
• Kayıt olmaya gelmiş
👤 TİP 2: Normal Kullanıcı
• Hiç davet almamış
• Uygulamayı kendi bulmuş
• Kendi mağazasını kurmak istiyor
B) Kayıt Formu (İKİSİ DE AYNI FORMU GÖRÜR):
Ad Soyad: [___________]
Telefon: [___________]
E-posta: [___________] ← BU ÖNEMLİ!
Şifre: [___________]
Şifre T.: [___________]
[KAYIT OL]
C) Kayıt Butonu Basıldığında Sistem Kontrol Eder:
🔍 Sistem Sorgusu:
// Bu email'e davet var mı?
checkInvitation(email) {
return firebase.collection('store_invitations')
.where('email', isEqualTo: email)
.where('status', isEqualTo: 'accepted')
.get();
}
📋 ADIM 4: İki Farklı Sonuç:
🎯 SENARYO A - Davetli Kullanıcı (email: yeni@kullanici.com):
if (davet_bulundu) {
// 1. Firebase Authentication hesap oluştur
createAccount(email, password);

// 2. User bilgilerini kaydet
users/{userId}: {
email: "yeni@kullanici.com",
name: "Ahmet Yılmaz",
phone: "555-123-4567",
role: "staff",
storeId: "store_xyz" ← Davet edilen mağaza
}

// 3. Mağaza üyelerine ekle
stores/store_xyz/members/{userId}: {
email: "yeni@kullanici.com",
name: "Ahmet Yılmaz",
role: "staff",
status: "accepted",
joinedAt: timestamp
}

// 4. Direkt dashboard'a git
Navigator.pushReplacement(MainScreen());
// Artık mağaza sahibi ile birlikte çalışıyor!
}
🎯 SENARYO B - Normal Kullanıcı (email: normal@kullanici.com):
if (davet_yok) {
// 1. Firebase Authentication hesap oluştur
createAccount(email, password);

// 2. User bilgilerini kaydet
users/{userId}: {
email: "normal@kullanici.com",
name: "Mehmet Özkan",
phone: "555-987-6543",
role: "owner",
storeId: "store\_" + userId ← YENİ mağaza ID'si
}

// 3. YENİ mağaza oluştur
stores/store\_{userId}: {
ownerId: userId,
name: "", // Boş - kullanıcı dolduracak
address: "", // Boş - kullanıcı dolduracak
phone: "", // Boş - kullanıcı dolduracak
isActive: true,
createdAt: timestamp
}

// 4. Kendini mağaza sahibi olarak ekle
stores/store\_{userId}/members/{userId}: {
email: "normal@kullanici.com",
name: "Mehmet Özkan",
role: "owner",
status: "owner",
joinedAt: timestamp
}

// 5. Mağaza kurulum sayfasına git
Navigator.pushReplacement(StoreSetupScreen());
// Mağaza bilgilerini dolduracak!
}
📧 ADIM 5: Email Bildirimi (YENİ - Eklenecek 📨)
sendInvitationEmail(email) {
subject: "StockPro'ya Davet Edildiniz"
body: "Mağaza takımına katılmak için uygulamayı indirin ve kayıt olun."
}
🚀 Özet Akış: 1. ✅ Davet sistemi → Çalışıyor 2. ✅ Onay sistemi → Çalışıyor 3. 🔧 Davetli kayıt → Mağazaya katılır 4. 🔧 Normal kayıt → Yeni mağaza kurar 5. 📨 Email bildirimi → Eklenecek
