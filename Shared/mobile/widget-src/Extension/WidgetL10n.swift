import Foundation

/// Widget ve Live Activity metinleri. Dil, uygulamanın App Group'a yazdığı
/// `appLanguage` değeridir (tr / en / ar / de); yoksa Türkçe.
///
/// Vakit adları paylaşılan veride kanonik Türkçe durur ("Öğle"); yalnız
/// gösterirken `WL.prayer(_:)` ile çevrilir.
enum WL {
  static var lang: String {
    let raw = UserDefaults(suiteName: appGroupID)?.string(forKey: "appLanguage") ?? "tr"
    return ["tr", "en", "ar", "de"].contains(raw) ? raw : "tr"
  }

  private static var index: Int {
    switch lang {
    case "en": return 1
    case "ar": return 2
    case "de": return 3
    default: return 0
    }
  }

  /// `%@` yer tutucuları sırayla `args` ile doldurulur.
  static func t(_ key: String, _ args: String...) -> String {
    guard let row = table[key] else { return key }
    // Almanca sütunu olmayan satırda İngilizcesi.
    var s = index < row.count ? row[index] : row[1]
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
    else if n.contains("iftar") { return t("ramadanW.iftar") }
    else if n.contains("sahur") { return t("ramadanW.sahur") }
    else { return nameOrKey }
    return t("prayer.\(key)")
  }

  static func amel(_ type: String) -> String { t("amel.\(type)") }

  private static let table: [String: [String]] = [
    "prayer.imsak": ["İmsak", "Imsak", "الإمساك", "Imsak"],
    "prayer.sabah": ["Sabah", "Fajr", "الفجر", "Fadschr"],
    "prayer.gunes": ["Güneş", "Sunrise", "الشروق", "Schuruq"],
    "prayer.ogle": ["Öğle", "Dhuhr", "الظهر", "Dhuhr"],
    "prayer.ikindi": ["İkindi", "Asr", "العصر", "Asr"],
    "prayer.aksam": ["Akşam", "Maghrib", "المغرب", "Maghrib"],
    "prayer.yatsi": ["Yatsı", "Isha", "العشاء", "Ischa"],

    "amel.quran": ["Kur'an", "Qur'an", "القرآن", "Koran"],
    "amel.nafile": ["Nafile", "Nafl", "النوافل", "Nafila"],
    "amel.fasting": ["Oruç", "Fasting", "الصيام", "Fasten"],
    "amel.sadaka": ["Sadaka", "Charity", "الصدقة", "Spende"],
    "amel.dua": ["Dua", "Dua", "الدعاء", "Dua"],
    "amel.memorization": ["Ezber", "Memorization", "الحفظ", "Auswendiglernen"],
    "amel.book": ["Kitap", "Book", "كتاب", "Buch"],

    "window.untilEnd": ["%@ vaktinin çıkmasına", "Until %@ ends", "حتى خروج وقت %@", "Bis %@ endet"],
    "window.until": ["%@ vaktine", "Until %@", "حتى %@", "Bis %@"],
    "window.ends": ["Çıkış %@", "Ends %@", "ينتهي %@", "Endet %@"],
    "window.starts": ["Giriş %@", "Starts %@", "يبدأ %@", "Beginnt %@"],
    "window.startsLabel": ["Giriş", "Starts", "يبدأ", "Beginnt"],
    "window.entered": ["Vakti girdi", "Time has begun", "دخل الوقت", "Die Gebetszeit hat begonnen"],
    "window.over": ["Vakit çıktı", "Time is over", "خرج الوقت", "Die Zeit ist vorbei"],
    "window.openApp": ["Vakitler için uygulamayı açın", "Open the app for prayer times", "افتح التطبيق لعرض المواقيت", "Öffne die App für die Gebetszeiten"],
    "window.waiting": ["Vakit bekleniyor", "Waiting for prayer time", "في انتظار الوقت", "Warten auf die Gebetszeit"],
    "window.none": ["Vakit yok", "No prayer time", "لا يوجد وقت", "Keine Gebetszeit"],
    "window.now": ["Şimdi", "Now", "الآن", "Jetzt"],
    "window.nowLower": ["şimdi", "now", "الآن", "jetzt"],
    "window.prayed": ["kılındı", "prayed", "صُلّيت", "gebetet"],

    "tracker.eyebrow": ["Namaz", "Prayer", "الصلاة", "Gebet"],
    "tracker.title": ["Namaz Takibi", "Prayer Tracker", "متابعة الصلاة", "Gebetstracker"],
    "tracker.allDone": ["Bugün tamamlandı", "Done for today", "اكتملت اليوم", "Für heute erledigt"],
    "tracker.allPending": ["5 vakit bekliyor", "5 prayers pending", "5 صلوات متبقية", "5 Gebete offen"],
    "tracker.left": ["%@ vakit kaldı", "%@ prayers left", "بقيت %@ صلوات", "%@ Gebete offen"],
    "tracker.markHint": ["Kıldım olarak işaretlemek için dokunun", "Tap to mark as prayed", "اضغط للتعليم كمُصلّاة", "Tippen, um als gebetet zu markieren"],
    "tracker.kaza": ["kaza olarak kılındı", "made up (qada)", "قُضيت", "nachgeholt (Qada)"],
    "tracker.done": ["kılındı", "prayed", "صُلّيت", "gebetet"],
    "tracker.notDone": ["kılınmadı", "not prayed", "لم تُصلَّ", "nicht gebetet"],
    "tracker.notYet": ["vakti girmedi", "not yet time", "لم يدخل وقتها", "noch nicht Zeit"],
    "tracker.desc.small": ["Bugün kılınan namazların özeti.", "Summary of today's prayers.", "ملخص صلوات اليوم.", "Übersicht der heutigen Gebete."],
    "tracker.desc.large": ["Günlük namaz takip durumu.", "Daily prayer tracking status.", "حالة متابعة الصلاة اليومية.", "Täglicher Stand deiner Gebete."],

    "amelW.eyebrow": ["İbadet", "Worship", "العبادة", "Gottesdienst"],
    "amelW.title": ["Bugünün İbadetleri", "Today's Worship", "عبادات اليوم", "Heutige Ibadat"],
    "amelW.none": ["Bugün kayıt yok", "Nothing logged today", "لا سجلات اليوم", "Heute nichts eingetragen"],
    "amelW.count": ["kayıt · %@ tür", "logged · %@ types", "مسجّل · %@ أنواع", "eingetragen · %@ Arten"],
    "amelW.logged": ["bugün kaydedildi", "logged today", "سُجّل اليوم", "heute eingetragen"],
    "amelW.notLogged": ["kayıt yok", "not logged", "غير مسجّل", "nicht eingetragen"],
    "ramadanW.fast.name": ["Oruç", "Fasting", "الصيام", "Fasten"],
    "ramadanW.fast.desc": ["Günün sayacı ve Ramazan oruçların.", "Today's countdown and your Ramadan fasts.", "عدّاد اليوم وصيامك في رمضان.", "Countdown für heute und deine Ramadan-Fastentage."],
    "ramadanW.table.name": ["İmsakiye", "Ramadan Timetable", "إمساكية رمضان", "Ramadan-Zeitplan"],
    "dhikrW.name": ["Zikirmatik", "Dhikr Counter", "المسبحة", "Dhikr-Zähler"],
    "goalsW.name": ["Hedeflerim", "My goals", "أهدافي", "Meine Ziele"],
    "goalsW.desc": ["Kaza borcu, bugünkü ezber tekrarı ve teheccüd.", "Make-up prayers, today's memorization review and tahajjud.", "الصلوات الفائتة ومراجعة الحفظ اليوم والتهجد.", "Nachzuholende Gebete, heutige Wiederholung und Tahadschud."],
    "goalsW.kaza": ["Kaza borcu", "Make-up", "القضاء", "Nachholen"],
    "goalsW.kazaDetail": ["vakit kaldı", "prayers left", "صلاة متبقية", "Gebete offen"],
    "goalsW.hifz": ["Ezber tekrarı", "Review", "المراجعة", "Wiederholung"],
    "goalsW.hifzDetail": ["ayet bugün", "verses today", "آية اليوم", "Verse heute"],
    "goalsW.hifzDone": ["bugünlük tamam", "done for today", "انتهت اليوم", "für heute erledigt"],
    "goalsW.hifzEmpty": ["ezber ekle", "add verses", "أضف آيات", "Verse hinzufügen"],
    "goalsW.teheccud": ["Teheccüd", "Tahajjud", "التهجد", "Tahadschud"],
    "goalsW.done": ["Kılındı", "Prayed", "صُلّيت", "Gebetet"],
    "goalsW.notYet": ["Henüz değil", "Not yet", "ليس بعد", "Noch nicht"],
    "goalsW.month": ["bu ay %@ gece", "%@ nights this month", "%@ ليلة هذا الشهر", "%@ Nächte diesen Monat"],
    "dhikrW.desc": ["Ana ekrandan dokunarak zikir ve tesbihat çek.", "Count dhikr and tasbih right from your Home Screen.", "سبّح واذكر من الشاشة الرئيسية بلمسة.", "Zähle Dhikr und Tasbih direkt vom Home-Bildschirm."],
    "dhikrW.eyebrow": ["Zikir", "Dhikr", "الذكر", "Dhikr"],
    "dhikrW.tesbihat": ["Tesbihat", "Tasbih", "التسبيح", "Tasbih"],
    "dhikrW.done": ["Tesbihat tamamlandı", "Tasbih complete", "اكتمل التسبيح", "Tasbih abgeschlossen"],
    "dhikrW.again": ["Yeniden başla", "Start again", "ابدأ من جديد", "Neu beginnen"],
    "dhikrW.today": ["Bugün %@", "Today %@", "اليوم %@", "Heute %@"],
    "dhikrW.undo": ["Geri al", "Undo", "تراجع", "Rückgängig"],
    "dhikrW.tapA11y": ["%@, %@. Saymak için dokun", "%@, %@. Tap to count", "%@، %@. اضغط للعد", "%@, %@. Tippen zum Zählen"],
    "dhikrW.subhanallah": ["Sübhânallâh", "Subhanallah", "سبحان الله", "Subhanallah"],
    "dhikrW.elhamdulillah": ["Elhamdülillâh", "Alhamdulillah", "الحمد لله", "Alhamdulillah"],
    "dhikrW.allahuekber": ["Allâhü ekber", "Allahu akbar", "الله أكبر", "Allahu akbar"],
    "dhikrW.tehlil": ["Lâ ilâhe illallâh", "La ilaha illallah", "لا إله إلا الله", "La ilaha illallah"],
    "dhikrW.istigfar": ["Estağfirullâh", "Astaghfirullah", "أستغفر الله", "Astaghfirullah"],
    "dhikrW.salavat": ["Salavat", "Salawat", "الصلاة على النبي", "Salawat"],
    "dhikrW.tesbihatClosing": ["Tehlil", "Tahlil", "التهليل", "Tahlil"],
    "ramadanW.table.desc": ["Önümüzdeki günlerin imsak ve iftar saatleri.", "Imsak and iftar times for the coming days.", "مواعيد الإمساك والإفطار للأيام القادمة.", "Imsak- und Iftarzeiten der kommenden Tage."],
    "ramadanW.lock.name": ["Ramazan", "Ramadan", "رمضان", "Ramadan"],
    "ramadanW.lock.desc": ["İftar sayacı ve oruç sayın kilit ekranında.", "Iftar countdown and fasts on the lock screen.", "عدّاد الإفطار وصيامك على شاشة القفل.", "Iftar-Countdown und Fastentage auf dem Sperrbildschirm."],
    "ramadanW.empty": ["Ramazan'da burada olacak", "Appears here during Ramadan", "يظهر هنا في رمضان", "Erscheint hier im Ramadan"],
    "ramadanW.day": ["%@. gün", "Day %@", "اليوم %@", "Tag %@"],
    "ramadanW.untilIftar": ["İftara kalan", "Until iftar", "حتى الإفطار", "Bis Iftar"],
    "ramadanW.untilSahur": ["Sahura kalan", "Until suhoor", "حتى السحور", "Bis Sahur"],
    "ramadanW.iftar": ["İftar", "Iftar", "الإفطار", "Iftar"],
    "ramadanW.sahur": ["Sahur", "Suhoor", "السحور", "Sahur"],
    "ramadanW.imsak": ["İmsak", "Imsak", "الإمساك", "Imsak"],
    "ramadanW.count": ["%@ / %@ gün oruç", "%@ / %@ days fasted", "%@ / %@ يوم صيام", "%@ / %@ Tage gefastet"],
    "amelW.name": ["İbadet Takibi", "Worship Tracker", "متابعة العبادات", "Ibadat-Tracker"],
    "amelW.desc": ["Günlük ibadet kayıtları.", "Daily worship logs.", "سجلات العبادة اليومية.", "Tägliche Ibadat-Einträge."],

    "insp.verse": ["Günün ayeti", "Verse of the day", "آية اليوم", "Vers des Tages"],
    "insp.hadith": ["Günün hadisi", "Hadith of the day", "حديث اليوم", "Hadith des Tages"],
    "insp.loading": ["Yükleniyor…", "Loading…", "جارٍ التحميل…", "Wird geladen…"],
    "insp.fallback": ["Günün ilhamı", "Daily inspiration", "إلهام اليوم", "Tägliche Inspiration"],
    "insp.name": ["Günün Hadisi / Ayeti", "Hadith / Verse of the Day", "حديث / آية اليوم", "Hadith / Vers des Tages"],
    "insp.desc": ["Günün ayeti ya da hadisi, kilit ekranında da.", "The verse or hadith of the day, also on the lock screen.", "آية أو حديث اليوم، على شاشة القفل أيضًا.", "Der Vers oder Hadith des Tages, auch auf dem Sperrbildschirm."],

    "times.current.name": ["Namaz Vakti", "Prayer Time", "وقت الصلاة", "Gebetszeit"],
    "times.current.desc": ["İçinde bulunulan vakit ve kalan süre.", "The current prayer time and time remaining.", "الوقت الحالي والمدة المتبقية.", "Die aktuelle Gebetszeit und die verbleibende Zeit."],
    "times.list.name": ["Namaz Vakitleri", "Prayer Times", "مواقيت الصلاة", "Gebetszeiten"],
    "times.list.desc": ["Günün namaz vakitleri.", "Today's prayer times.", "مواقيت صلاة اليوم.", "Die heutigen Gebetszeiten."],

    "standby.desc": [
      "Standby modu için büyük namaz vakti sayacı. iPhone şarjda ve yatay duruyorken görünür.",
      "A large prayer countdown for StandBy. Shown while iPhone is charging in landscape.",
      "عدّاد كبير لوقت الصلاة لوضع الاستعداد. يظهر أثناء شحن iPhone بالوضع الأفقي.",
    ],
    "premium.cta": ["Premium'a geç", "Go Premium", "اشترك في بريميوم", "Premium holen"],

    "alarmW.open": ["Alarmlar", "Alarms", "المنبّهات", "Wecker"],
    "alarmW.next": ["Sıradaki alarm %@", "Next alarm %@", "المنبّه التالي %@", "Nächster Wecker %@"],

    "ring.name": ["Gün Çemberi", "Day Circle", "دائرة اليوم", "Tageskreis"],
    "ring.desc": [
      "Günün vakitleri ve kerahat vakitleri tek çemberde.",
      "Today's prayer and makruh times in one circle.",
      "مواقيت اليوم وأوقات الكراهة في دائرة واحدة.",
    ],
    "ring.forbidden": ["Kerahat", "Makruh", "كراهة", "Makruh"],
  ]
}
