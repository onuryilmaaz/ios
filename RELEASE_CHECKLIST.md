# SwiftUI geçişi: kalan kabul kontrolleri

Kod incelemesi: 18 Ekim 2026. Bu liste uygulanan kod ile cihazda/serviste doğrulanması gerekenleri ayırır. Premium kapalı; Paywall/RevenueCat açılışa dahil değil.

Bu dosya ayrı iOS deposuna taşınmıştır. `mobile/` ve `Node-Ts/` adları önceki çalışma alanındaki ayrı React Native ve backend depolarını anlatır. `build/` altındaki test/arşiv çıktıları yereldir ve Git'e eklenmez.

## Hazır olan kod

- Admin: panel, aramalı ve sayfalı kullanıcı listesi, kullanıcı ayrıntısı, aktif/pasif hesap, premium verme/kaldırma, rol atama/kaldırma, oturum kapatma ve rol CRUD. Profilde admin bağlantısı var. Yetkisiz kullanıcıya içerik gösterilmez; sunucu da bütün `/admin` uçlarında admin rolü ister. Admin metinleri proje kuralı gereği RN'deki gibi Türkçe.
- Apple: son onaydan sonra taze yetki kodu alınır. Sunucu kodu token'a çevirir; imza, issuer, audience ve saklı Apple kullanıcı kimliğini doğruladıktan sonra `/auth/revoke` çağırır. Ağ çağrıları süre sınırlıdır. Apple'a ulaşılamaması hesap silme talebini engellemez; eski istemcilerin gövdesiz DELETE isteği çalışır. Apple belgesi: [TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).
- Veri taşıma: RN AsyncStorage kısa/MD5 dosya değerleri ve eski Expo dizinleri okunur; kaynak dosyalar korunur. Tamamlanamayan taşıma yeniden denenir; kısmi taşımada kullanıcı değişiklikleri korunur. Eski AsyncStorage/App Group token'ları doğrulanarak Keychain'e geçirilir; daha taze widget token'ı ve çıkış damgası korunur.
- Kuyruk: RN JSON'u/tarih/clientRef korunur. Gönderim sürerken ekleme, silme ve düzenleme kaybolmaz. Oturum hazır olmadan gönderilmez. 401/403/408/429, 5xx ve ağ hatasında kayıtlar tutulur; kalıcı diğer 4xx atlanır. Başarıdan sonra güncel depodan yalnız gönderilen kayıt çıkarılır.

## Yapılandırma

- [ ] TestFlight arşivinden önce App Store Connect'teki en son sürüm/build değerini kontrol et. `project.yml` şu an `MARKETING_VERSION: 1.1.0`, `CURRENT_PROJECT_VERSION: 1`; RN `mobile/app.json` build 6 ve EAS `autoIncrement: true` kullanıyordu. Yeni `1.1.0` build kimliği benzersiz olmalı; build değerini seçip `xcodegen generate` çalıştır, sonra Xcode'da Release/`com.onur6541.salah` ile dağıtım imzalı arşiv al. Bu listedeki `Salah-email-ready-2026.10.19.xcarchive` yalnız imzasız derleme doğrulamasıdır.
- [x] Yeni iOS API adresi: `https://api.onur-yilmaz.com/salah`. Kullanıcı VPS'te `/root/Projects/salah-api` klasörünü `salah-api` PM2 süreciyle 3001 portunda açtı. Cloudflare proxy ve mevcut wildcard Origin sertifikasıyla Nginx `/salah/` önekini kaldırarak iletir. Kullanıcının dış `/salah/health` çıktısı `status: ok`; PM2 süreç listesi kaydedildi ve `pm2-root.service` etkin. Güncel yapılandırmada hem Release hem Debug bu adrese gider; izole test/önizleme argümanları API'yi kapatır. Tam uygulama kabulü ve sunucu yeniden başlatma testi henüz yapılmadı.
- [x] `project.yml` içinde Debug ve Release için ayrı `GOOGLE_IOS_CLIENT_ID` değerleri tanımlı.
- [ ] Google girişinin gerçek cihaz kabulü ve backend `GOOGLE_CLIENT_IDS` eşleşmesi. Client ID gizli anahtar değildir; `.p8` dosyası/özel anahtar sohbete veya repoya konmamalı.
- [ ] Apple Developer Sign in with Apple anahtarı: backend ortamında `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`; izinli istemciler `APPLE_BUNDLE_IDS` (varsayılan mağaza ve Dev bundle ID'leri). Özel anahtar uygulama paketine girmez. Bu incelemede mevcut gizli değerler okunmadı/değiştirilmedi.
- [ ] Minimum iOS 17 kararı; RN'nin desteklediği iOS 15–16 kullanıcıları son RN sürümünde kalacak.
- [ ] Ayrı staging veritabanı. Yerel backend'in canlı DB kullanması staging kabulü değildir. Bu incelemede backend deploy edilmedi; testler DB'ye bağlanmadı.

## RN üstüne güncelleme: üç cihaz/hesap

Salah Dev ayrı bundle ID'dir; mağaza uygulamasının veri devrini doğrulamaz. Aynı bundle ID, takım, Keychain grubu ve App Group ile imzalanmış TestFlight sürümü RN'nin üstüne kurulmalı. Uygulamayı arada silmeyin.

| Senaryo | Cihaz/hesap 1 | Cihaz/hesap 2 | Cihaz/hesap 3 |
|---|---|---|---|
| RN'de giriş; tema/dil/ilçe, Kur'an son okuma ve alarm/bildirim tercihlerini kaydet | [ ] | [ ] | [ ] |
| Çevrimdışı namaz ve ibadet kayıtları ekle; bir kaydı iptal et | [ ] | [ ] | [ ] |
| SwiftUI sürümünü üstüne kur; internet yokken oturum ve veriyi kontrol et | [ ] | [ ] | [ ] |
| İnterneti aç; bekleyenler doğru tarih ve sırayla bir kez gönderilsin | [ ] | [ ] | [ ] |
| Yeniden başlat; onboarding tekrarlanmasın, seri ve kayıtlar doğru kalsın | [ ] | [ ] | [ ] |
| Mevcut widget'lar kalsın; Kıldım, Live Activity ve alarmlar çalışsın | [ ] | [ ] | [ ] |

SQLite envanteri: RN `Documents/SQLite/hadiths_v2.db` paketlenmiş hadis kataloğunun kopyasıdır; kişisel kayıt tablosu yoktur. Native aynı paket verisini okur; eski katalog silinmez. Kullanıcı yedek JSON'ları Documents'ta olduğu gibi kalır. Clerk SDK oturumunun kendisi native'e taşınmaz; uygulamanın ortak backend token'ı ve `auth_user` korunur.

## Gerçek servis ve cihaz kabulü

- [ ] Apple test hesabıyla giriş → silme → Apple yetkisinin kalkması → yeniden kayıt. Apple penceresini iptal etmek silme isteği göndermemeli. Eski Clerk/çoklu sağlayıcı bağlantılı Apple hesaplarının native Apple girişiyle eşleşmesi ayrıca doğrulanmalı; mevcut backend tek `auth_provider/provider_id` tutar.
- [ ] Admin test hesabında sayfalama/arama, rol CRUD, rol atama/kaldırma, premium ve oturum yönetimi. Yıkıcı işlemler için ayrı test hesabı/veritabanı kullanın; canlıdaki gerçek kullanıcıları kabul testi amacıyla değiştirmeyin.
- [ ] Bildirim izinleri, ön/arka plan/kapalı uygulamada ses; AlarmKit (iOS 26+) sessiz mod, Kıldım/Ertele; kilit ekranı/Dynamic Island push ve widget Kıldım.
- [ ] Kıble sensörü/kalibrasyon, Kur'an ve hutbe ses kesintileri/arka plan, Mushaf yatay yön/zoom, paylaşım/PDF.
- [ ] Auth token yenileme: geçici 503 oturumu kapatmasın; kesin 400/401 kapanmayı tetiklesin. Asistan/dua önerisi ve Özel Gün seri/muafiyet etkileri uçtan uca doğrulansın.
- [ ] RN referanslarıyla 3 dil × 2 tema; küçük ve büyük iPhone; erişilebilir yazı boyutları. Üretilmiş native görüntüler tek başına piksel eşleşmesi kabulü değildir.
- [ ] TestFlight iç/dış beta, Sentry hata/çökme karşılaştırması ve kademeli yayın. Backend dağıtımını ayrı backend deposunda koordine et.

## Yeniden doğrulama

Swift: `xcodegen generate`, sonra Salah şemasında Test. Test şeması `SALAH_TEST_ISOLATED=1` ile API ve kuyruk gönderimini kapatır. Taşıma testleri geçici dosyalar/ayrı UserDefaults ve sahte Keychain kullanır.

### Splash kontrolü

Xcode'da `Salah.xcodeproj` → `Salah` → iPhone simülatörü → Run. Normal açılış zümrüt zemin üzerinde altın hilal/yıldız ve amber Bungee SALAH animasyonuyla başlar; tanıtımı bitirmiş kullanıcı ana sayfaya, yeni kullanıcı onboarding'e geçer. Açılış ağ yanıtını beklemez. Arka plandan dönüşte yeniden oynatılmaz; uygulama tamamen kapatılıp açılınca oynatılır.

Scheme → Run → Arguments içinde aşağıdakilerle canlı API'ye bağlanmadan kontrol edilebilir (Release'te etkisiz):

```text
-SalahDebugOffline YES -SalahDebugSplash YES
-rn.@salah_onboarding_done true
-rn.@salah_language tr -rn.@salah_theme_mode dark
```

`true` yerine `false`: yeni kullanıcı geçişi. Dil `tr|en|ar`, tema `light|dark`. Sabit logo karesi için `-SalahDebugSplashFrame brand`; ilk zemin karesi için `start`. Animasyonu denemeden önce bu argümanı kaldırın. Hareket azaltma önizlemesi: `-SalahDebugReduceMotion YES`. Gerçek cihazda Ayarlar → Erişilebilirlik → Hareket → Hareketi Azalt ile de kontrol edin. Normal açılışa dönmeden önce önizleme argümanlarını kaldırın.

- [ ] Fiziksel cihazda ilk kurulum/güncelleme, soğuk açılış, arka plandan dönüş, VoiceOver ve Hareketi Azalt kabulü.

### Giriş paneli ve e-posta formları

Misafirken Kur'an, İbadet, Sor veya namaz takip düğmesine dokununca tam ekran karşılama paneli açılır. Çarpı paneli kapatır; e-posta seçimi yenilenen giriş ekranına, Kayıt Ol bağlantısı kayıt ekranına götürür. Geri düğmesi önceki ekrana döner. Debug'da canlı API olmadan doğrudan önizleme: `-SalahDebugOffline YES -SalahDebugAuth welcome|login|register -rn.@salah_onboarding_done true`; dil `-rn.@salah_language tr|en|ar`, tema `-rn.@salah_theme_mode light|dark`. Bu argümanlar Release'te etkisizdir.

- [x] İzole simülatör kabulü: misafir sekmeleri/namaz takibi, tam ekran panelin kapatılması, e-posta giriş/kayıt yönlendirmesi ve boş alan hataları. UI testleri ve TR/EN/AR × iki tema görüntüleri: `build/TestResults/Auth-guest-final-2026.10.19.xcresult`, `build/TestResults/Email-forms-2026.10.19.xcresult`, `build/EmailFormScreenshots/`, `build/AuthPanelScreenshots-2026.10.19/`. Son kaynaklardan imzasız Release arşivi: `build/Archives/Salah-email-ready-2026.10.19.xcarchive`.
- [ ] Gerçek cihazda Apple/Google/e-posta oturumu, şifre sıfırlama, kayıt/doğrulama, klavye ve VoiceOver ile uçtan uca kabul. Bu testler canlı hesap işlemi yapmadı.

Backend'in tamamını çalıştırmadan yalnız DB'siz testler (ayrı backend deposunda):

```sh
bun test src/services/__tests__/apple-revoke.test.ts src/services/__tests__/account-deletion.test.ts
bun run typecheck
```

Admin görsel önizlemesi (API kapalı, tüm yazmalar reddedilir): `-SalahDebugOffline YES -SalahDebugAdmin YES -SalahDebugRoute admin|adminUsers|adminDetail|adminRoles -rn.@salah_onboarding_done true`. Dil/tema için mevcut `-rn.@salah_language` ve `-rn.@salah_theme_mode` argümanları kullanılır. Bu araçlar Release'te etkisizdir.
