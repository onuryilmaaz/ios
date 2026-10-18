/**
 * Yasal metinler — Gizlilik Politikası ve Kullanım Koşulları (TR + EN).
 * Uygulama içi LegalModal tarafından okunur.
 *
 * NOT: Bu metinler genel bir şablondur; mümkünse bir hukukçuya gözden geçirt.
 * App Store Connect ayrıca herkese açık bir Gizlilik Politikası URL'i (web)
 * istediği için aynı metni basit bir web sayfasında da yayınla
 * (bkz. proje kökü: legal-site/index.html → GitHub Pages).
 */

type LegalSection = { title: string; body: string };
type LegalDoc = { heading: string; updated: string; sections: LegalSection[] };

const SUPPORT_EMAIL = 'onuryilm.41@gmail.com';

export const LEGAL: {
  privacy: { tr: LegalDoc; en: LegalDoc };
  terms: { tr: LegalDoc; en: LegalDoc };
} = {
  privacy: {
    tr: {
      heading: 'Gizlilik Politikası',
      updated: 'Son güncelleme: 5 Ekim 2026',
      sections: [
        {
          title: '1. Genel',
          body: 'Salah ("uygulama", "biz") gizliliğinize önem verir. Bu politika, uygulamayı kullandığınızda hangi verileri topladığımızı, bunları nasıl kullandığımızı ve haklarınızı açıklar. Uygulamayı kullanarak bu politikayı kabul etmiş olursunuz.',
        },
        {
          title: '2. Topladığımız Veriler',
          body: '• Hesap bilgileri: e-posta, ad-soyad, kullanıcı adı, (varsa) telefon, cinsiyet ve profil fotoğrafı.\n• İbadet ve aktivite verileri: namaz kayıtları, Kuran okuma, oruç, sadaka ve dua kayıtları.\n• Konum: namaz vakitleri ve kıble yönü için (yalnızca uygulamayı kullanırken).\n• Cihaz ve bildirim: bildirim gönderebilmek için push token ve temel cihaz bilgileri.',
        },
        {
          title: '3. Verileri Nasıl Kullanıyoruz',
          body: 'Verilerinizi yalnızca; hesabınızı yönetmek, ibadet takibi sunmak, namaz vakti/kıble gibi özellikleri sağlamak, bildirim göndermek, uygulamayı iyileştirmek ve güvenliği sağlamak için kullanırız. Verilerinizi reklam amacıyla satmayız ve üçüncü taraflara pazarlama için aktarmayız.',
        },
        {
          title: '4. Üçüncü Taraf Hizmetler',
          body: "Hizmeti sağlamak için bazı güvenilir sağlayıcılarla çalışırız:\n• Clerk — Google/Apple ile güvenli giriş ve kimlik doğrulama.\n• Sentry — çökme ve hata teşhisi.\n• Cloudinary — profil görselleri.\n• Apple / Google Play / RevenueCat — abonelik işlemleri; kart bilgilerinizi biz görmeyiz.\n• İçerik API'leri (Diyanet, quran.com, islamic.network) — namaz vakti, Kuran ve hadis içeriği.",
        },
        {
          title: '5. Konum Verisi',
          body: 'Konumunuz yalnızca uygulamayı kullanırken ve izin verdiğinizde alınır; namaz vakitlerini hesaplamak, ve kıble yönünü göstermek için kullanılır. Konumunuz reklam veya takip amacıyla kullanılmaz. İzni cihaz ayarlarından dilediğiniz zaman kapatabilirsiniz.',
        },
        {
          title: '6. Veri Saklama ve Güvenlik',
          body: 'Verileriniz, hesabınız aktif olduğu sürece saklanır. Verileri yetkisiz erişime karşı korumak için makul teknik ve idari önlemler (şifreli bağlantı, erişim kısıtları) uygularız. Hiçbir sistem %100 güvenli olmasa da güvenliği sağlamak için sürekli çalışırız.',
        },
        {
          title: '7. Haklarınız',
          body: 'KVKK ve ilgili mevzuat kapsamında; verilerinize erişme, düzeltme, dışa aktarma ve silme haklarına sahipsiniz. Verilerinizi uygulama içindeki "Verilerimi Yedekle" ile JSON olarak dışa aktarabilirsiniz.',
        },
        {
          title: '8. Hesap ve Veri Silme',
          body: 'Hesabınızı ve tüm verilerinizi uygulama içinden kalıcı olarak silebilirsiniz: Ayarlar → Hesap → "Hesabımı Kalıcı Olarak Sil". Bu işlem geri alınamaz ve tüm ibadet kayıtlarınız kalıcı olarak silinir. Uygulamaya erişiminiz yoksa, hesabınıza kayıtlı e-posta adresinden onuryilm.41@gmail.com adresine "Hesap silme talebi" konulu bir e-posta göndererek de silme talep edebilirsiniz; talebiniz en geç 30 gün içinde işlenir.',
        },
        {
          title: '9. Değişiklikler ve İletişim',
          body: `Bu politikayı zaman zaman güncelleyebiliriz; önemli değişiklikleri uygulama üzerinden bildiririz. Sorularınız için: ${SUPPORT_EMAIL}`,
        },
      ],
    },
    en: {
      heading: 'Privacy Policy',
      updated: 'Last updated: October 5, 2026',
      sections: [
        {
          title: '1. Overview',
          body: 'Salah ("the app", "we") respects your privacy. This policy explains what data we collect when you use the app, how we use it, and your rights. By using the app, you agree to this policy.',
        },
        {
          title: '2. Data We Collect',
          body: "• Account info: email, name, username, phone (optional), gender, and profile photo.\n• Worship & activity data: prayer logs, Qur'an reading, fasting, charity, and dua records.\n• Location: for prayer times and qibla direction (only while using the app).\n• Device & notifications: push token and basic device info to send notifications.",
        },
        {
          title: '3. How We Use Data',
          body: 'We use your data only to manage your account, provide worship tracking, deliver features like prayer times/qibla, send notifications, improve the app, and ensure security. We do not sell your data for advertising or share it with third parties for marketing.',
        },
        {
          title: '4. Third-Party Services',
          body: "We rely on trusted providers to deliver the service:\n• Clerk — secure sign-in and authentication with Google/Apple.\n• Sentry — crash and error diagnostics.\n• Cloudinary — profile images.\n• Apple / Google Play / RevenueCat — subscription processing; we never see your card details.\n• Content APIs (Diyanet, quran.com, islamic.network) — prayer times, Qur'an, and hadith content.",
        },
        {
          title: '5. Location Data',
          body: 'Your location is accessed only while using the app and with your permission, to calculate prayer times, and show qibla direction. It is never used for advertising or tracking. You can disable the permission at any time in your device settings.',
        },
        {
          title: '6. Data Retention & Security',
          body: 'Your data is retained while your account is active. We apply reasonable technical and organizational measures (encrypted connections, access controls) to protect it from unauthorized access. No system is 100% secure, but we work continuously to keep your data safe.',
        },
        {
          title: '7. Your Rights',
          body: 'You have the right to access, correct, export, and delete your data. You can export your data as JSON via "Back Up My Data" in the app.',
        },
        {
          title: '8. Account & Data Deletion',
          body: 'You can permanently delete your account and all data from within the app: Settings → Account → "Permanently Delete My Account". This is irreversible and permanently removes all your worship records. If you no longer have access to the app, you can also request deletion by emailing onuryilm.41@gmail.com from the address registered to your account with the subject "Account deletion request"; requests are processed within 30 days.',
        },
        {
          title: '9. Changes & Contact',
          body: `We may update this policy from time to time and will notify you of significant changes in the app. Questions: ${SUPPORT_EMAIL}`,
        },
      ],
    },
  },
  terms: {
    tr: {
      heading: 'Kullanım Koşulları',
      updated: 'Son güncelleme: 5 Ekim 2026',
      sections: [
        {
          title: '1. Koşulların Kabulü',
          body: "Salah uygulamasını kullanarak bu Kullanım Koşulları'nı kabul etmiş olursunuz. Koşulları kabul etmiyorsanız lütfen uygulamayı kullanmayın.",
        },
        {
          title: '2. Hesap ve Sorumluluklar',
          body: 'Hesabınızın güvenliğinden ve hesabınız altında gerçekleşen işlemlerden siz sorumlusunuz. Kayıt sırasında doğru bilgi vermeyi ve giriş bilgilerinizi gizli tutmayı kabul edersiniz.',
        },
        {
          title: '3. Kabul Edilebilir Kullanım',
          body: 'Uygulamayı yalnızca yasal amaçlarla kullanmayı kabul edersiniz. Uygulamaya zarar vermek, başkalarının haklarını ihlal etmek, izinsiz erişim sağlamak veya hizmeti kötüye kullanmak yasaktır.',
        },
        {
          title: '4. Dini İçerik Hakkında',
          body: 'Namaz vakitleri, kıble yönü ve diğer dini içerikler üçüncü taraf kaynaklardan ve hesaplamalardan elde edilir; yaklaşık değerler içerebilir. Önemli durumlarda yerel resmi kaynaklardan teyit etmeniz önerilir. Bu bilgilerin doğruluğu konusunda kesin garanti veremeyiz.',
        },
        {
          title: '5. Fikri Mülkiyet',
          body: 'Uygulamanın tasarımı, logosu, yazılımı ve özgün içeriği bize aittir ve telif haklarıyla korunur. İzinsiz kopyalanamaz, dağıtılamaz veya türev çalışma oluşturulamaz. Üçüncü taraf içerikleri ilgili sahiplerine aittir.',
        },
        {
          title: '6. Abonelikler ve Satın Alımlar',
          body: 'Uygulama şu anda temel özellikleriyle ücretsizdir. Premium abonelik ödemeleri Apple App Store veya Google Play üzerinden işlenir; ücretlendirme, yenileme ve iade koşulları ilgili mağazanın kurallarına tabidir. Aboneliği App Store ya da Google Play abonelik ayarlarından yönetebilir veya iptal edebilirsiniz.',
        },
        {
          title: '7. Hizmetin Sonlandırılması',
          body: 'Bu koşulları ihlal etmeniz halinde hesabınızı askıya alma veya sonlandırma hakkımız saklıdır. Siz de dilediğiniz zaman hesabınızı uygulama içinden silebilirsiniz.',
        },
        {
          title: '8. Garanti Reddi ve Sorumluluk Sınırı',
          body: 'Uygulama "olduğu gibi" sunulur. Yürürlükteki yasaların izin verdiği ölçüde, uygulamanın kesintisiz veya hatasız olacağını garanti etmeyiz ve dolaylı zararlardan sorumlu tutulamayız.',
        },
        {
          title: '9. Uygulanacak Hukuk',
          body: 'Bu koşullar Türkiye Cumhuriyeti yasalarına tabidir ve bu yasalara göre yorumlanır.',
        },
        {
          title: '10. Değişiklikler ve İletişim',
          body: `Bu koşulları zaman zaman güncelleyebiliriz. Güncellemelerden sonra uygulamayı kullanmaya devam etmeniz yeni koşulları kabul ettiğiniz anlamına gelir. İletişim: ${SUPPORT_EMAIL}`,
        },
      ],
    },
    en: {
      heading: 'Terms of Use',
      updated: 'Last updated: October 5, 2026',
      sections: [
        {
          title: '1. Acceptance of Terms',
          body: 'By using the Salah app, you agree to these Terms of Use. If you do not accept these terms, please do not use the app.',
        },
        {
          title: '2. Account & Responsibilities',
          body: 'You are responsible for the security of your account and for activity that occurs under it. You agree to provide accurate information at sign-up and to keep your login credentials confidential.',
        },
        {
          title: '3. Acceptable Use',
          body: "You agree to use the app only for lawful purposes. Harming the app, infringing others' rights, gaining unauthorized access, or misusing the service is prohibited.",
        },
        {
          title: '4. About Religious Content',
          body: 'Prayer times, qibla direction, and other religious content are derived from third-party sources and calculations and may be approximate. For important matters, we recommend verifying with local official sources. We cannot guarantee absolute accuracy of this information.',
        },
        {
          title: '5. Intellectual Property',
          body: "The app's design, logo, software, and original content belong to us and are protected by copyright. They may not be copied, distributed, or used to create derivative works without permission. Third-party content belongs to its respective owners.",
        },
        {
          title: '6. Subscriptions & Purchases',
          body: "The app is currently free with its core features. Premium subscription payments are processed through the Apple App Store or Google Play; billing, renewal, and refund terms are subject to the respective store's rules. You can manage or cancel a subscription in your App Store or Google Play subscription settings.",
        },
        {
          title: '7. Termination',
          body: 'We reserve the right to suspend or terminate your account if you violate these terms. You may also delete your account at any time from within the app.',
        },
        {
          title: '8. Disclaimer & Limitation of Liability',
          body: 'The app is provided "as is". To the extent permitted by applicable law, we do not warrant that the app will be uninterrupted or error-free, and we are not liable for indirect damages.',
        },
        {
          title: '9. Governing Law',
          body: 'These terms are governed by and construed in accordance with the laws of the Republic of Türkiye.',
        },
        {
          title: '10. Changes & Contact',
          body: `We may update these terms from time to time. Continuing to use the app after updates means you accept the new terms. Contact: ${SUPPORT_EMAIL}`,
        },
      ],
    },
  },
};
