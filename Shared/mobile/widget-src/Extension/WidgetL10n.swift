import Foundation

/// Widget ve Live Activity metinleri. Dil, uygulamanın App Group'a yazdığı
/// `appLanguage` değeridir (tr / en / ar); yoksa Türkçe.
///
/// Vakit adları paylaşılan veride kanonik Türkçe durur ("Öğle"); yalnız
/// gösterirken `WL.prayer(_:)` ile çevrilir.
enum WL {
  static var lang: String {
    let raw = UserDefaults(suiteName: appGroupID)?.string(forKey: "appLanguage") ?? "tr"
    return ["tr", "en", "ar"].contains(raw) ? raw : "tr"
  }

  private static var index: Int {
    switch lang {
    case "en": return 1
    case "ar": return 2
    default: return 0
    }
  }

  /// `%@` yer tutucuları sırayla `args` ile doldurulur.
  static func t(_ key: String, _ args: String...) -> String {
    guard let row = table[key] else { return key }
    var s = row[index]
    for a in args {
      if let r = s.range(of: "%@") { s.replaceSubrange(r, with: a) }
    }
    return s
  }

  /// Kanonik (Türkçe) vakit adı ya da anahtarı → seçili dilde ad.
  static func prayer(_ nameOrKey: String) -> String {
    let n = nameOrKey.lowercased(with: Locale(identifier: "tr_TR"))
    let key: String
    if n.contains("imsak") { key = "imsak" }
    else if n.contains("sabah") || n.contains("fajr") { key = "sabah" }
    else if n.contains("güneş") || n.contains("gunes") { key = "gunes" }
    else if n.contains("öğle") || n.contains("ogle") { key = "ogle" }
    else if n.contains("ikindi") { key = "ikindi" }
    else if n.contains("akşam") || n.contains("aksam") { key = "aksam" }
    else if n.contains("yatsı") || n.contains("yatsi") { key = "yatsi" }
    else { return nameOrKey }
    return t("prayer.\(key)")
  }

  static func amel(_ type: String) -> String { t("amel.\(type)") }

  private static let table: [String: [String]] = [
    "prayer.imsak": ["İmsak", "Imsak", "الإمساك"],
    "prayer.sabah": ["Sabah", "Fajr", "الفجر"],
    "prayer.gunes": ["Güneş", "Sunrise", "الشروق"],
    "prayer.ogle": ["Öğle", "Dhuhr", "الظهر"],
    "prayer.ikindi": ["İkindi", "Asr", "العصر"],
    "prayer.aksam": ["Akşam", "Maghrib", "المغرب"],
    "prayer.yatsi": ["Yatsı", "Isha", "العشاء"],

    "amel.quran": ["Kur'an", "Qur'an", "القرآن"],
    "amel.nafile": ["Nafile", "Nafl", "النوافل"],
    "amel.fasting": ["Oruç", "Fasting", "الصيام"],
    "amel.sadaka": ["Sadaka", "Charity", "الصدقة"],
    "amel.dua": ["Dua", "Dua", "الدعاء"],
    "amel.memorization": ["Ezber", "Memorization", "الحفظ"],
    "amel.book": ["Kitap", "Book", "كتاب"],

    "window.untilEnd": ["%@ vaktinin çıkmasına", "Until %@ ends", "حتى خروج وقت %@"],
    "window.until": ["%@ vaktine", "Until %@", "حتى %@"],
    "window.ends": ["Çıkış %@", "Ends %@", "ينتهي %@"],
    "window.starts": ["Giriş %@", "Starts %@", "يبدأ %@"],
    "window.startsLabel": ["Giriş", "Starts", "يبدأ"],
    "window.entered": ["Vakti girdi", "Time has begun", "دخل الوقت"],
    "window.over": ["Vakit çıktı", "Time is over", "خرج الوقت"],
    "window.openApp": ["Vakitler için uygulamayı açın", "Open the app for prayer times", "افتح التطبيق لعرض المواقيت"],
    "window.waiting": ["Vakit bekleniyor", "Waiting for prayer time", "في انتظار الوقت"],
    "window.none": ["Vakit yok", "No prayer time", "لا يوجد وقت"],
    "window.now": ["Şimdi", "Now", "الآن"],
    "window.nowLower": ["şimdi", "now", "الآن"],
    "window.prayed": ["kılındı", "prayed", "صُلّيت"],

    "tracker.eyebrow": ["Namaz", "Prayer", "الصلاة"],
    "tracker.title": ["Namaz Takibi", "Prayer Tracker", "متابعة الصلاة"],
    "tracker.allDone": ["Bugün tamamlandı", "Done for today", "اكتملت اليوم"],
    "tracker.allPending": ["5 vakit bekliyor", "5 prayers pending", "5 صلوات متبقية"],
    "tracker.left": ["%@ vakit kaldı", "%@ prayers left", "بقيت %@ صلوات"],
    "tracker.markHint": ["Kıldım olarak işaretlemek için dokunun", "Tap to mark as prayed", "اضغط للتعليم كمُصلّاة"],
    "tracker.kaza": ["kaza olarak kılındı", "made up (qada)", "قُضيت"],
    "tracker.done": ["kılındı", "prayed", "صُلّيت"],
    "tracker.notDone": ["kılınmadı", "not prayed", "لم تُصلَّ"],
    "tracker.notYet": ["vakti girmedi", "not yet time", "لم يدخل وقتها"],
    "tracker.desc.small": ["Bugün kılınan namazların özeti.", "Summary of today's prayers.", "ملخص صلوات اليوم."],
    "tracker.desc.large": ["Günlük namaz takip durumu.", "Daily prayer tracking status.", "حالة متابعة الصلاة اليومية."],

    "amelW.eyebrow": ["İbadet", "Worship", "العبادة"],
    "amelW.title": ["Bugünün İbadetleri", "Today's Worship", "عبادات اليوم"],
    "amelW.none": ["Bugün kayıt yok", "Nothing logged today", "لا سجلات اليوم"],
    "amelW.count": ["kayıt · %@ tür", "logged · %@ types", "مسجّل · %@ أنواع"],
    "amelW.logged": ["bugün kaydedildi", "logged today", "سُجّل اليوم"],
    "amelW.notLogged": ["kayıt yok", "not logged", "غير مسجّل"],
    "amelW.name": ["İbadet Takibi", "Worship Tracker", "متابعة العبادات"],
    "amelW.desc": ["Günlük ibadet kayıtları.", "Daily worship logs.", "سجلات العبادة اليومية."],

    "insp.verse": ["Günün ayeti", "Verse of the day", "آية اليوم"],
    "insp.hadith": ["Günün hadisi", "Hadith of the day", "حديث اليوم"],
    "insp.loading": ["Yükleniyor…", "Loading…", "جارٍ التحميل…"],
    "insp.fallback": ["Günün ilhamı", "Daily inspiration", "إلهام اليوم"],
    "insp.name": ["Günün Hadisi / Ayeti", "Hadith / Verse of the Day", "حديث / آية اليوم"],
    "insp.desc": ["Günün ayeti ya da hadisi, kilit ekranında da.", "The verse or hadith of the day, also on the lock screen.", "آية أو حديث اليوم، على شاشة القفل أيضًا."],

    "times.current.name": ["Namaz Vakti", "Prayer Time", "وقت الصلاة"],
    "times.current.desc": ["İçinde bulunulan vakit ve kalan süre.", "The current prayer time and time remaining.", "الوقت الحالي والمدة المتبقية."],
    "times.list.name": ["Namaz Vakitleri", "Prayer Times", "مواقيت الصلاة"],
    "times.list.desc": ["Günün namaz vakitleri.", "Today's prayer times.", "مواقيت صلاة اليوم."],

    "standby.desc": [
      "Standby modu için büyük namaz vakti sayacı. iPhone şarjda ve yatay duruyorken görünür.",
      "A large prayer countdown for StandBy. Shown while iPhone is charging in landscape.",
      "عدّاد كبير لوقت الصلاة لوضع الاستعداد. يظهر أثناء شحن iPhone بالوضع الأفقي.",
    ],
    "premium.cta": ["Premium'a geç", "Go Premium", "اشترك في بريميوم"],

    "alarmW.open": ["Alarmlar", "Alarms", "المنبّهات"],
    "alarmW.next": ["Sıradaki alarm %@", "Next alarm %@", "المنبّه التالي %@"],

    "ring.name": ["Gün Çemberi", "Day Circle", "دائرة اليوم"],
    "ring.desc": [
      "Günün vakitleri ve kerahat vakitleri tek çemberde.",
      "Today's prayer and makruh times in one circle.",
      "مواقيت اليوم وأوقات الكراهة في دائرة واحدة.",
    ],
    "ring.forbidden": ["Kerahat", "Makruh", "كراهة"],
  ]
}
