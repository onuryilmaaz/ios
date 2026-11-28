import Foundation

/// Widget ve Live Activity metinleri. Dil, uygulamanın App Group'a yazdığı
/// `appLanguage` değeridir (`languages`); yoksa Türkçe.
///
/// Vakit adları paylaşılan veride kanonik Türkçe durur ("Öğle"); yalnız
/// gösterirken `WL.prayer(_:)` ile çevrilir.
enum WL {
  /// Sütun sırası: tr, en, ar, de, fr, id, ur, ru, es, it, ms, bn, hi, th.
  static let languages = ["tr", "en", "ar", "de", "fr", "id", "ur", "ru", "es", "it", "ms", "bn", "hi", "th"]

  static var lang: String {
    let raw = UserDefaults(suiteName: appGroupID)?.string(forKey: "appLanguage") ?? "tr"
    return languages.contains(raw) ? raw : "tr"
  }

  private static var index: Int { languages.firstIndex(of: lang) ?? 0 }

  /// `%@` yer tutucuları sırayla `args` ile doldurulur.
  static func t(_ key: String, _ args: String...) -> String {
    guard let row = table[key] else { return key }
    // Dilin sütunu olmayan satırda İngilizcesi.
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
    "prayer.imsak": ["İmsak", "Imsak", "الإمساك", "Imsak", "Imsak", "Imsak", "امساک", "Имсак", "Imsak", "Imsak", "Imsak", "ইমসাক", "इमसाक़", "อิมซาก"],
    "prayer.sabah": ["Sabah", "Fajr", "الفجر", "Fadschr", "Fajr", "Subuh", "فجر", "Фаджр", "Fajr", "Fajr", "Subuh", "ফজর", "फ़ज्र", "ฟัจร์"],
    "prayer.gunes": ["Güneş", "Sunrise", "الشروق", "Schuruq", "Chourouq", "Terbit", "طلوع", "Восход", "Shuruq", "Shuruq", "Syuruk", "সূর্যোদয়", "सूर्योदय", "ตะวันขึ้น"],
    "prayer.ogle": ["Öğle", "Dhuhr", "الظهر", "Dhuhr", "Dhuhr", "Zuhur", "ظہر", "Зухр", "Dhuhr", "Dhuhr", "Zuhur", "যোহর", "ज़ुहर", "ซุฮร์"],
    "prayer.ikindi": ["İkindi", "Asr", "العصر", "Asr", "Asr", "Asar", "عصر", "Аср", "Asr", "Asr", "Asar", "আসর", "अस्र", "อัสร์"],
    "prayer.aksam": ["Akşam", "Maghrib", "المغرب", "Maghrib", "Maghrib", "Magrib", "مغرب", "Магриб", "Maghrib", "Maghrib", "Maghrib", "মাগরিব", "मग़रिब", "มัฆริบ"],
    "prayer.yatsi": ["Yatsı", "Isha", "العشاء", "Ischa", "Isha", "Isya", "عشاء", "Иша", "Isha", "Isha", "Isyak", "ইশা", "इशा", "อิชาอ์"],

    "amel.quran": ["Kur'an", "Qur'an", "القرآن", "Koran", "Coran", "Al-Qur'an", "قرآن", "Коран", "Corán", "Corano", "Al-Quran", "কুরআন", "क़ुरआन", "อัลกุรอาน"],
    "amel.nafile": ["Nafile", "Nafl", "النوافل", "Nafila", "Nafila", "Sunah", "نفل", "Нафиля", "Nafl", "Nafl", "Sunat", "নফল", "नफ़िल", "นาฟิละฮ์"],
    "amel.fasting": ["Oruç", "Fasting", "الصيام", "Fasten", "Jeûne", "Puasa", "روزہ", "Пост", "Ayuno", "Digiuno", "Puasa", "রোজা", "रोज़ा", "การถือศีลอด"],
    "amel.sadaka": ["Sadaka", "Charity", "الصدقة", "Spende", "Aumône", "Sedekah", "صدقہ", "Садака", "Caridad", "Carità", "Sedekah", "সদকা", "सदक़ा", "ซะดะเกาะฮ์"],
    "amel.dua": ["Dua", "Dua", "الدعاء", "Dua", "Dua", "Doa", "دعا", "Дуа", "Dua", "Dua", "Doa", "দোয়া", "दुआ", "ดุอาอ์"],
    "amel.memorization": ["Ezber", "Memorization", "الحفظ", "Auswendiglernen", "Mémorisation", "Hafalan", "حفظ", "Заучивание", "Memorización", "Memorizzazione", "Hafazan", "মুখস্থ", "हिफ़्ज़", "การท่องจำ"],
    "amel.book": ["Kitap", "Book", "كتاب", "Buch", "Livre", "Buku", "کتاب", "Книга", "Libro", "Libro", "Buku", "বই", "किताब", "หนังสือ"],

    "window.untilEnd": ["%@ vaktinin çıkmasına", "Until %@ ends", "حتى خروج وقت %@", "Bis %@ endet", "Jusqu'à la fin de %@", "Hingga %@ berakhir", "%@ ختم ہونے تک", "До конца: %@", "Hasta que termine %@", "Fino alla fine di %@", "Sehingga %@ tamat", "%@ শেষ হতে", "%@ समाप्त होने तक", "จนกว่า %@ จะหมดเวลา"],
    "window.until": ["%@ vaktine", "Until %@", "حتى %@", "Bis %@", "Jusqu'à %@", "Menuju %@", "%@ تک", "До: %@", "Hasta %@", "Fino a %@", "Menuju %@", "%@ পর্যন্ত", "%@ तक", "จนถึง %@"],
    "window.ends": ["Çıkış %@", "Ends %@", "ينتهي %@", "Endet %@", "Fin %@", "Berakhir %@", "ختم %@", "Конец %@", "Termina %@", "Finisce %@", "Tamat %@", "শেষ %@", "समाप्त %@", "สิ้นสุด %@"],
    "window.starts": ["Giriş %@", "Starts %@", "يبدأ %@", "Beginnt %@", "Début %@", "Mulai %@", "شروع %@", "Начало %@", "Empieza %@", "Inizia %@", "Bermula %@", "শুরু %@", "शुरू %@", "เริ่ม %@"],
    "window.startsLabel": ["Giriş", "Starts", "يبدأ", "Beginnt", "Début", "Mulai", "شروع", "Начало", "Empieza", "Inizia", "Bermula", "শুরু", "शुरू", "เริ่ม"],
    "window.entered": ["Vakti girdi", "Time has begun", "دخل الوقت", "Die Gebetszeit hat begonnen", "L'heure a commencé", "Waktu telah masuk", "وقت شروع ہو گیا", "Время наступило", "Ha comenzado la hora", "L'orario è iniziato", "Waktu telah masuk", "ওয়াক্ত শুরু হয়েছে", "वक़्त शुरू हो गया", "เข้าเวลาแล้ว"],
    "window.over": ["Vakit çıktı", "Time is over", "خرج الوقت", "Die Zeit ist vorbei", "L'heure est passée", "Waktu telah habis", "وقت ختم ہو گیا", "Время истекло", "La hora ha terminado", "L'orario è terminato", "Waktu telah tamat", "ওয়াক্ত শেষ", "वक़्त ख़त्म हो गया", "หมดเวลาแล้ว"],
    "window.openApp": ["Vakitler için uygulamayı açın", "Open the app for prayer times", "افتح التطبيق لعرض المواقيت", "Öffne die App für die Gebetszeiten", "Ouvrez l'app pour les horaires de prière", "Buka aplikasi untuk waktu salat", "نماز کے اوقات کے لیے ایپ کھولیں", "Откройте приложение для времени намазов", "Abre la app para ver los horarios", "Apri l'app per gli orari di preghiera", "Buka aplikasi untuk waktu solat", "নামাজের সময়ের জন্য অ্যাপ খুলুন", "नमाज़ के समय के लिए ऐप खोलें", "เปิดแอปเพื่อดูเวลาละหมาด"],
    "window.waiting": ["Vakit bekleniyor", "Waiting for prayer time", "في انتظار الوقت", "Warten auf die Gebetszeit", "En attente de l'heure de prière", "Menunggu waktu salat", "نماز کے وقت کا انتظار", "Ожидание времени намаза", "Esperando la hora de oración", "In attesa dell'orario di preghiera", "Menunggu waktu solat", "নামাজের ওয়াক্তের অপেক্ষা", "नमाज़ के वक़्त का इंतज़ार", "รอเวลาละหมาด"],
    "window.none": ["Vakit yok", "No prayer time", "لا يوجد وقت", "Keine Gebetszeit", "Aucune heure de prière", "Tidak ada waktu salat", "نماز کا وقت نہیں", "Нет времени намаза", "Sin hora de oración", "Nessun orario di preghiera", "Tiada waktu solat", "কোনো ওয়াক্ত নেই", "कोई वक़्त नहीं", "ไม่มีเวลาละหมาด"],
    "window.now": ["Şimdi", "Now", "الآن", "Jetzt", "Maintenant", "Sekarang", "ابھی", "Сейчас", "Ahora", "Adesso", "Sekarang", "এখন", "अभी", "ตอนนี้"],
    "window.nowLower": ["şimdi", "now", "الآن", "jetzt", "maintenant", "sekarang", "ابھی", "сейчас", "ahora", "adesso", "sekarang", "এখন", "अभी", "ตอนนี้"],
    "window.prayed": ["kılındı", "prayed", "صُلّيت", "gebetet", "accomplie", "sudah salat", "ادا کی", "совершён", "realizada", "eseguita", "sudah solat", "আদায়", "अदा की", "ละหมาดแล้ว"],

    "tracker.eyebrow": ["Namaz", "Prayer", "الصلاة", "Gebet", "Prière", "Salat", "نماز", "Намаз", "Oración", "Preghiera", "Solat", "নামাজ", "नमाज़", "ละหมาด"],
    "tracker.title": ["Namaz Takibi", "Prayer Tracker", "متابعة الصلاة", "Gebetstracker", "Suivi des prières", "Pelacak Salat", "نماز ٹریکر", "Трекер намазов", "Seguimiento de oraciones", "Tracker delle preghiere", "Penjejak Solat", "নামাজ ট্র্যাকার", "नमाज़ ट्रैकर", "ติดตามการละหมาด"],
    "tracker.allDone": ["Bugün tamamlandı", "Done for today", "اكتملت اليوم", "Für heute erledigt", "Terminé pour aujourd'hui", "Selesai untuk hari ini", "آج کے لیے مکمل", "На сегодня всё", "Hecho por hoy", "Completato per oggi", "Selesai untuk hari ini", "আজকের জন্য সম্পন্ন", "आज के लिए पूरा", "เสร็จสำหรับวันนี้"],
    "tracker.allPending": ["5 vakit bekliyor", "5 prayers pending", "5 صلوات متبقية", "5 Gebete offen", "5 prières en attente", "5 salat tertunda", "5 نمازیں باقی", "5 намазов впереди", "5 oraciones pendientes", "5 preghiere da fare", "5 solat belum dikerjakan", "৫ ওয়াক্ত বাকি", "5 नमाज़ें बाकी", "เหลือ 5 เวลา"],
    "tracker.left": ["%@ vakit kaldı", "%@ prayers left", "بقيت %@ صلوات", "%@ Gebete offen", "Encore %@ prières", "%@ salat lagi", "%@ نمازیں باقی", "Осталось намазов: %@", "Faltan %@ oraciones", "Mancano %@ preghiere", "%@ solat lagi", "%@ ওয়াক্ত বাকি", "%@ नमाज़ें बाकी", "เหลืออีก %@ เวลา"],
    "tracker.markHint": ["Kıldım olarak işaretlemek için dokunun", "Tap to mark as prayed", "اضغط للتعليم كمُصلّاة", "Tippen, um als gebetet zu markieren", "Touchez pour marquer comme accomplie", "Ketuk untuk menandai sudah salat", "ادا شدہ درج کرنے کے لیے ٹیپ کریں", "Нажмите, чтобы отметить", "Toca para marcar como realizada", "Tocca per segnare come eseguita", "Ketik untuk tandakan sudah solat", "আদায় চিহ্নিত করতে ট্যাপ করুন", "अदा दर्ज करने के लिए टैप करें", "แตะเพื่อทำเครื่องหมายว่าละหมาดแล้ว"],
    "tracker.kaza": ["kaza olarak kılındı", "made up (qada)", "قُضيت", "nachgeholt (Qada)", "rattrapée (qada)", "sudah diqada", "قضا ادا کی", "возмещён (каза)", "recuperada (qada)", "recuperata (qada)", "sudah diqada", "কাযা আদায়", "क़ज़ा अदा की", "ละหมาดชดเชยแล้ว"],
    "tracker.done": ["kılındı", "prayed", "صُلّيت", "gebetet", "accomplie", "sudah salat", "ادا کی", "совершён", "realizada", "eseguita", "sudah solat", "আদায়", "अदा की", "ละหมาดแล้ว"],
    "tracker.notDone": ["kılınmadı", "not prayed", "لم تُصلَّ", "nicht gebetet", "non accomplie", "belum salat", "ادا نہیں کی", "не совершён", "no realizada", "non eseguita", "belum solat", "আদায় হয়নি", "अदा नहीं की", "ยังไม่ได้ละหมาด"],
    "tracker.notYet": ["vakti girmedi", "not yet time", "لم يدخل وقتها", "noch nicht Zeit", "pas encore l'heure", "belum waktunya", "ابھی وقت نہیں ہوا", "время не наступило", "aún no es la hora", "non è ancora l'ora", "belum waktunya", "এখনো ওয়াক্ত হয়নি", "अभी वक़्त नहीं हुआ", "ยังไม่ถึงเวลา"],
    "tracker.desc.small": ["Bugün kılınan namazların özeti.", "Summary of today's prayers.", "ملخص صلوات اليوم.", "Übersicht der heutigen Gebete.", "Résumé des prières du jour.", "Ringkasan salat hari ini.", "آج کی نمازوں کا خلاصہ۔", "Итоги намазов за сегодня.", "Resumen de las oraciones de hoy.", "Riepilogo delle preghiere di oggi.", "Ringkasan solat hari ini.", "আজকের নামাজের সারাংশ।", "आज की नमाज़ों का सार।", "สรุปการละหมาดของวันนี้"],
    "tracker.desc.large": ["Günlük namaz takip durumu.", "Daily prayer tracking status.", "حالة متابعة الصلاة اليومية.", "Täglicher Stand deiner Gebete.", "Suivi quotidien des prières.", "Status pelacakan salat harian.", "روزانہ نماز کے ریکارڈ کی صورتحال۔", "Ежедневный учёт намазов.", "Estado diario de tus oraciones.", "Stato giornaliero delle preghiere.", "Status penjejakan solat harian.", "দৈনিক নামাজের অবস্থা।", "रोज़ाना नमाज़ की स्थिति।", "สถานะการติดตามการละหมาดรายวัน"],

    "amelW.eyebrow": ["İbadet", "Worship", "العبادة", "Gottesdienst", "Adoration", "Ibadah", "عبادت", "Поклонение", "Adoración", "Culto", "Ibadah", "ইবাদত", "इबादत", "อิบาดะฮ์"],
    "amelW.title": ["Bugünün İbadetleri", "Today's Worship", "عبادات اليوم", "Heutige Ibadat", "Adorations du jour", "Ibadah Hari Ini", "آج کی عبادات", "Поклонения за сегодня", "Adoración de hoy", "Ibadat di oggi", "Ibadah Hari Ini", "আজকের ইবাদত", "आज की इबादत", "อิบาดะฮ์วันนี้"],
    "amelW.none": ["Bugün kayıt yok", "Nothing logged today", "لا سجلات اليوم", "Heute nichts eingetragen", "Rien de noté aujourd'hui", "Belum ada catatan hari ini", "آج کچھ درج نہیں", "Сегодня ничего не отмечено", "Nada registrado hoy", "Niente registrato oggi", "Tiada catatan hari ini", "আজ কিছু লেখা হয়নি", "आज कुछ दर्ज नहीं", "วันนี้ยังไม่มีบันทึก"],
    "amelW.count": ["kayıt · %@ tür", "logged · %@ types", "مسجّل · %@ أنواع", "eingetragen · %@ Arten", "noté · %@ types", "tercatat · %@ jenis", "درج · %@ اقسام", "отмечено · видов: %@", "registrado · %@ tipos", "registrato · %@ tipi", "dicatat · %@ jenis", "লেখা · %@ ধরন", "दर्ज · %@ प्रकार", "บันทึกแล้ว · %@ ประเภท"],
    "amelW.logged": ["bugün kaydedildi", "logged today", "سُجّل اليوم", "heute eingetragen", "noté aujourd'hui", "tercatat hari ini", "آج درج", "отмечено сегодня", "registrado hoy", "registrato oggi", "dicatat hari ini", "আজ লেখা হয়েছে", "आज दर्ज", "บันทึกวันนี้แล้ว"],
    "amelW.notLogged": ["kayıt yok", "not logged", "غير مسجّل", "nicht eingetragen", "non noté", "belum dicatat", "درج نہیں", "не отмечено", "sin registrar", "non registrato", "belum dicatat", "লেখা হয়নি", "दर्ज नहीं", "ยังไม่บันทึก"],
    "ramadanW.fast.name": ["Oruç", "Fasting", "الصيام", "Fasten", "Jeûne", "Puasa", "روزہ", "Пост", "Ayuno", "Digiuno", "Puasa", "রোজা", "रोज़ा", "การถือศีลอด"],
    "ramadanW.fast.desc": ["Günün sayacı ve Ramazan oruçların.", "Today's countdown and your Ramadan fasts.", "عدّاد اليوم وصيامك في رمضان.", "Countdown für heute und deine Ramadan-Fastentage.", "Le compte à rebours du jour et vos jeûnes du Ramadan.", "Hitung mundur hari ini dan puasa Ramadan Anda.", "آج کی الٹی گنتی اور آپ کے رمضان کے روزے۔", "Обратный отсчёт на сегодня и ваши посты в Рамадан.", "La cuenta atrás de hoy y tus ayunos de Ramadán.", "Il conto alla rovescia di oggi e i tuoi digiuni del Ramadan.", "Kiraan detik hari ini dan puasa Ramadan anda.", "আজকের কাউন্টডাউন ও রমজানের রোজা।", "आज की उल्टी गिनती और रमज़ान के रोज़े।", "นับถอยหลังวันนี้และการถือศีลอดเดือนรอมฎอน"],
    "ramadanW.table.name": ["İmsakiye", "Ramadan Timetable", "إمساكية رمضان", "Ramadan-Zeitplan", "Calendrier du Ramadan", "Jadwal Ramadan", "رمضان کا نظام الاوقات", "Расписание Рамадана", "Horario de Ramadán", "Orari del Ramadan", "Jadual Ramadan", "রমজানের সময়সূচি", "रमज़ान की समय-सारणी", "ตารางเวลารอมฎอน"],
    "dhikrW.name": ["Zikirmatik", "Dhikr Counter", "المسبحة", "Dhikr-Zähler", "Compteur de dhikr", "Penghitung Zikir", "ذکر کاؤنٹر", "Счётчик зикра", "Contador de dhikr", "Contatore di dhikr", "Pembilang Zikir", "জিকির কাউন্টার", "ज़िक्र काउंटर", "ตัวนับซิกิร"],
    "goalsW.name": ["Hedeflerim", "My goals", "أهدافي", "Meine Ziele", "Mes objectifs", "Target saya", "میرے اہداف", "Мои цели", "Mis objetivos", "I miei obiettivi", "Sasaran saya", "আমার লক্ষ্য", "मेरे लक्ष्य", "เป้าหมายของฉัน"],
    "goalsW.desc": ["Kaza borcu, bugünkü ezber tekrarı ve teheccüd.", "Make-up prayers, today's memorization review and tahajjud.", "الصلوات الفائتة ومراجعة الحفظ اليوم والتهجد.", "Nachzuholende Gebete, heutige Wiederholung und Tahadschud.", "Prières à rattraper, révision du jour et tahajjud.", "Salat qada, murajaah hafalan hari ini, dan tahajud.", "قضا نمازیں، آج کا حفظ کا دہرانا اور تہجد۔", "Каза-намазы, повторение на сегодня и тахаджуд.", "Oraciones por recuperar, repaso de memorización de hoy y tahajjud.", "Preghiere da recuperare, ripasso di oggi e tahajjud.", "Solat qada, ulang kaji hafazan hari ini dan tahajud.", "কাযা নামাজ, আজকের মুখস্থ পুনরাবৃত্তি ও তাহাজ্জুদ।", "क़ज़ा नमाज़ें, आज का हिफ़्ज़ दोहराव और तहज्जुद।", "ละหมาดชดเชย ทบทวนท่องจำวันนี้ และตะฮัจญุด"],
    "goalsW.kaza": ["Kaza borcu", "Make-up", "القضاء", "Nachholen", "Rattrapage", "Qada", "قضا", "Каза", "Recuperar", "Recupero", "Qada", "কাযা", "क़ज़ा", "ชดเชย"],
    "goalsW.kazaDetail": ["vakit kaldı", "prayers left", "صلاة متبقية", "Gebete offen", "prières restantes", "salat tersisa", "نمازیں باقی", "намазов осталось", "oraciones pendientes", "preghiere rimaste", "solat tersisa", "ওয়াক্ত বাকি", "नमाज़ें बाकी", "เวลาที่เหลือ"],
    "goalsW.hifz": ["Ezber tekrarı", "Review", "المراجعة", "Wiederholung", "Révision", "Murajaah", "دہرائی", "Повторение", "Repaso", "Ripasso", "Ulang kaji", "পুনরাবৃত্তি", "दोहराव", "ทบทวน"],
    "goalsW.hifzDetail": ["ayet bugün", "verses today", "آية اليوم", "Verse heute", "versets aujourd'hui", "ayat hari ini", "آج کی آیات", "аятов сегодня", "versículos hoy", "versetti oggi", "ayat hari ini", "আজ আয়াত", "आज की आयतें", "อายะฮ์วันนี้"],
    "goalsW.hifzDone": ["bugünlük tamam", "done for today", "انتهت اليوم", "für heute erledigt", "terminé pour aujourd'hui", "selesai hari ini", "آج کے لیے مکمل", "на сегодня готово", "hecho por hoy", "completato per oggi", "selesai hari ini", "আজকের জন্য সম্পন্ন", "आज के लिए पूरा", "เสร็จสำหรับวันนี้"],
    "goalsW.hifzEmpty": ["ezber ekle", "add verses", "أضف آيات", "Verse hinzufügen", "ajouter des versets", "tambah ayat", "آیات شامل کریں", "добавьте аяты", "añade versículos", "aggiungi versetti", "tambah ayat", "আয়াত যোগ করুন", "आयतें जोड़ें", "เพิ่มอายะฮ์"],
    "goalsW.teheccud": ["Teheccüd", "Tahajjud", "التهجد", "Tahadschud", "Tahajjud", "Tahajud", "تہجد", "Тахаджуд", "Tahajjud", "Tahajjud", "Tahajud", "তাহাজ্জুদ", "तहज्जुद", "ตะฮัจญุด"],
    "goalsW.done": ["Kılındı", "Prayed", "صُلّيت", "Gebetet", "Accompli", "Dikerjakan", "ادا کی", "Совершён", "Realizada", "Eseguita", "Dikerjakan", "আদায়", "अदा की", "ละหมาดแล้ว"],
    "goalsW.notYet": ["Henüz değil", "Not yet", "ليس بعد", "Noch nicht", "Pas encore", "Belum", "ابھی نہیں", "Ещё нет", "Aún no", "Non ancora", "Belum", "এখনো না", "अभी नहीं", "ยังไม่"],
    "goalsW.month": ["bu ay %@ gece", "%@ nights this month", "%@ ليلة هذا الشهر", "%@ Nächte diesen Monat", "%@ nuits ce mois-ci", "%@ malam bulan ini", "اس مہینے %@ راتیں", "Ночей в этом месяце: %@", "%@ noches este mes", "%@ notti questo mese", "%@ malam bulan ini", "এই মাসে %@ রাত", "इस महीने %@ रातें", "%@ คืนในเดือนนี้"],
    "dhikrW.desc": ["Ana ekrandan dokunarak zikir ve tesbihat çek.", "Count dhikr and tasbih right from your Home Screen.", "سبّح واذكر من الشاشة الرئيسية بلمسة.", "Zähle Dhikr und Tasbih direkt vom Home-Bildschirm.", "Comptez dhikr et tasbih depuis l'écran d'accueil.", "Hitung zikir dan tasbih langsung dari layar utama.", "ہوم اسکرین سے ہی ذکر اور تسبیح گنیں۔", "Считайте зикр и тасбих прямо с главного экрана.", "Cuenta dhikr y tasbih desde la pantalla de inicio.", "Conta dhikr e tasbih direttamente dalla schermata Home.", "Kira zikir dan tasbih terus dari skrin utama.", "হোম স্ক্রিন থেকেই জিকির ও তাসবিহ গুনুন।", "होम स्क्रीन से ही ज़िक्र और तस्बीह गिनें।", "นับซิกิรและตัสบีห์ได้จากหน้าจอโฮม"],
    "dhikrW.eyebrow": ["Zikir", "Dhikr", "الذكر", "Dhikr", "Dhikr", "Zikir", "ذکر", "Зикр", "Dhikr", "Dhikr", "Zikir", "জিকির", "ज़िक्र", "ซิกิร"],
    "dhikrW.tesbihat": ["Tesbihat", "Tasbih", "التسبيح", "Tasbih", "Tasbih", "Tasbih", "تسبیح", "Тасбих", "Tasbih", "Tasbih", "Tasbih", "তাসবিহ", "तस्बीह", "ตัสบีห์"],
    "dhikrW.done": ["Tesbihat tamamlandı", "Tasbih complete", "اكتمل التسبيح", "Tasbih abgeschlossen", "Tasbih terminé", "Tasbih selesai", "تسبیح مکمل", "Тасбих завершён", "Tasbih completado", "Tasbih completato", "Tasbih selesai", "তাসবিহ সম্পন্ন", "तस्बीह पूरी", "ตัสบีห์เสร็จแล้ว"],
    "dhikrW.again": ["Yeniden başla", "Start again", "ابدأ من جديد", "Neu beginnen", "Recommencer", "Mulai lagi", "دوبارہ شروع کریں", "Начать снова", "Empezar de nuevo", "Ricomincia", "Mulakan semula", "আবার শুরু করুন", "फिर से शुरू करें", "เริ่มใหม่"],
    "dhikrW.today": ["Bugün %@", "Today %@", "اليوم %@", "Heute %@", "Aujourd'hui %@", "Hari ini %@", "آج %@", "Сегодня %@", "Hoy %@", "Oggi %@", "Hari ini %@", "আজ %@", "आज %@", "วันนี้ %@"],
    "dhikrW.undo": ["Geri al", "Undo", "تراجع", "Rückgängig", "Annuler", "Urungkan", "واپس", "Отменить", "Deshacer", "Annulla", "Buat asal", "পূর্বাবস্থা", "वापस", "เลิกทำ"],
    "dhikrW.tapA11y": ["%@, %@. Saymak için dokun", "%@, %@. Tap to count", "%@، %@. اضغط للعد", "%@, %@. Tippen zum Zählen", "%@, %@. Touchez pour compter", "%@, %@. Ketuk untuk menghitung", "%@، %@۔ گننے کے لیے ٹیپ کریں", "%@, %@. Нажмите, чтобы считать", "%@, %@. Toca para contar", "%@, %@. Tocca per contare", "%@, %@. Ketik untuk mengira", "%@, %@। গুনতে ট্যাপ করুন", "%@, %@। गिनने के लिए टैप करें", "%@, %@ แตะเพื่อนับ"],
    "dhikrW.subhanallah": ["Sübhânallâh", "Subhanallah", "سبحان الله", "Subhanallah", "Subhanallah", "Subhanallah", "سبحان اللہ", "Субханаллах", "Subhanallah", "Subhanallah", "Subhanallah", "সুবহানাল্লাহ", "सुब्हानल्लाह", "สุบหานัลลอฮ์"],
    "dhikrW.elhamdulillah": ["Elhamdülillâh", "Alhamdulillah", "الحمد لله", "Alhamdulillah", "Alhamdulillah", "Alhamdulillah", "الحمد للہ", "Альхамдулиллях", "Alhamdulillah", "Alhamdulillah", "Alhamdulillah", "আলহামদুলিল্লাহ", "अल्हम्दुलिल्लाह", "อัลหัมดุลิลลาห์"],
    "dhikrW.allahuekber": ["Allâhü ekber", "Allahu akbar", "الله أكبر", "Allahu akbar", "Allahu akbar", "Allahu akbar", "اللہ اکبر", "Аллаху акбар", "Allahu akbar", "Allahu akbar", "Allahu akbar", "আল্লাহু আকবার", "अल्लाहु अकबर", "อัลลอฮุอักบัร"],
    "dhikrW.tehlil": ["Lâ ilâhe illallâh", "La ilaha illallah", "لا إله إلا الله", "La ilaha illallah", "La ilaha illallah", "La ilaha illallah", "لا الٰہ الا اللہ", "Ля иляха илляллах", "La ilaha illallah", "La ilaha illallah", "La ilaha illallah", "লা ইলাহা ইল্লাল্লাহ", "ला इलाहा इल्लल्लाह", "ลาอิลาฮะ อิลลัลลอฮ์"],
    "dhikrW.istigfar": ["Estağfirullâh", "Astaghfirullah", "أستغفر الله", "Astaghfirullah", "Astaghfirullah", "Astagfirullah", "استغفر اللہ", "Астагфируллах", "Astaghfirullah", "Astaghfirullah", "Astaghfirullah", "আস্তাগফিরুল্লাহ", "अस्तग़फिरुल्लाह", "อัสตัฆฟิรุลลอฮ์"],
    "dhikrW.salavat": ["Salavat", "Salawat", "الصلاة على النبي", "Salawat", "Salawat", "Selawat", "درود", "Салават", "Salawat", "Salawat", "Selawat", "দরুদ", "दुरूद", "เศาะละวาต"],
    "dhikrW.tesbihatClosing": ["Tehlil", "Tahlil", "التهليل", "Tahlil", "Tahlil", "Tahlil", "تہلیل", "Тахлиль", "Tahlil", "Tahlil", "Tahlil", "তাহলীল", "तहलील", "ตะฮ์ลีล"],
    "ramadanW.table.desc": ["Önümüzdeki günlerin imsak ve iftar saatleri.", "Imsak and iftar times for the coming days.", "مواعيد الإمساك والإفطار للأيام القادمة.", "Imsak- und Iftarzeiten der kommenden Tage.", "Horaires d'imsak et d'iftar des prochains jours.", "Waktu imsak dan berbuka untuk hari-hari mendatang.", "آنے والے دنوں کے سحری اور افطار کے اوقات۔", "Время имсака и ифтара на ближайшие дни.", "Horarios de imsak e iftar de los próximos días.", "Orari di imsak e iftar dei prossimi giorni.", "Waktu imsak dan berbuka untuk hari-hari akan datang.", "আগামী দিনগুলোর সাহরি ও ইফতারের সময়।", "आने वाले दिनों के सहरी और इफ़्तार के समय।", "เวลาอิมซากและอิฟฏอร์สำหรับวันข้างหน้า"],
    "ramadanW.lock.name": ["Ramazan", "Ramadan", "رمضان", "Ramadan", "Ramadan", "Ramadan", "رمضان", "Рамадан", "Ramadán", "Ramadan", "Ramadan", "রমজান", "रमज़ान", "รอมฎอน"],
    "ramadanW.lock.desc": ["İftar sayacı ve oruç sayın kilit ekranında.", "Iftar countdown and fasts on the lock screen.", "عدّاد الإفطار وصيامك على شاشة القفل.", "Iftar-Countdown und Fastentage auf dem Sperrbildschirm.", "Compte à rebours de l'iftar et jeûnes sur l'écran verrouillé.", "Hitung mundur berbuka dan puasa di layar kunci.", "لاک اسکرین پر افطار کی الٹی گنتی اور روزے۔", "Отсчёт до ифтара и посты на экране блокировки.", "Cuenta atrás del iftar y ayunos en la pantalla de bloqueo.", "Conto alla rovescia dell'iftar e digiuni nella schermata di blocco.", "Kiraan detik berbuka dan puasa pada skrin kunci.", "লক স্ক্রিনে ইফতারের কাউন্টডাউন ও রোজা।", "लॉक स्क्रीन पर इफ़्तार की उल्टी गिनती और रोज़े।", "นับถอยหลังอิฟฏอร์และการถือศีลอดบนหน้าจอล็อก"],
    "ramadanW.empty": ["Ramazan'da burada olacak", "Appears here during Ramadan", "يظهر هنا في رمضان", "Erscheint hier im Ramadan", "Apparaît ici pendant le Ramadan", "Muncul di sini selama Ramadan", "رمضان میں یہاں نظر آتا ہے", "Появится здесь в Рамадан", "Aparece aquí durante Ramadán", "Appare qui durante il Ramadan", "Dipaparkan di sini semasa Ramadan", "রমজানে এখানে দেখা যাবে", "रमज़ान में यहाँ दिखेगा", "จะแสดงที่นี่ในช่วงรอมฎอน"],
    "ramadanW.day": ["%@. gün", "Day %@", "اليوم %@", "Tag %@", "Jour %@", "Hari ke-%@", "دن %@", "День %@", "Día %@", "Giorno %@", "Hari ke-%@", "%@ তম দিন", "दिन %@", "วันที่ %@"],
    "ramadanW.untilIftar": ["İftara kalan", "Until iftar", "حتى الإفطار", "Bis Iftar", "Jusqu'à l'iftar", "Menuju berbuka", "افطار تک", "До ифтара", "Hasta el iftar", "Fino all'iftar", "Menuju berbuka", "ইফতার পর্যন্ত", "इफ़्तार तक", "จนถึงอิฟฏอร์"],
    "ramadanW.untilSahur": ["Sahura kalan", "Until suhoor", "حتى السحور", "Bis Sahur", "Jusqu'au suhur", "Menuju sahur", "سحری تک", "До сухура", "Hasta el suhur", "Fino al suhur", "Menuju sahur", "সাহরি পর্যন্ত", "सहरी तक", "จนถึงซุฮูร"],
    "ramadanW.iftar": ["İftar", "Iftar", "الإفطار", "Iftar", "Iftar", "Berbuka", "افطار", "Ифтар", "Iftar", "Iftar", "Berbuka", "ইফতার", "इफ़्तार", "อิฟฏอร์"],
    "ramadanW.sahur": ["Sahur", "Suhoor", "السحور", "Sahur", "Suhur", "Sahur", "سحری", "Сухур", "Suhur", "Suhur", "Sahur", "সাহরি", "सहरी", "ซุฮูร"],
    "ramadanW.imsak": ["İmsak", "Imsak", "الإمساك", "Imsak", "Imsak", "Imsak", "امساک", "Имсак", "Imsak", "Imsak", "Imsak", "ইমসাক", "इमसाक़", "อิมซาก"],
    "ramadanW.count": ["%@ / %@ gün oruç", "%@ / %@ days fasted", "%@ / %@ يوم صيام", "%@ / %@ Tage gefastet", "%@ / %@ jours jeûnés", "%@ / %@ hari berpuasa", "%@ / %@ دن روزہ رکھا", "%@ / %@ дней поста", "%@ / %@ días de ayuno", "%@ / %@ giorni di digiuno", "%@ / %@ hari berpuasa", "%@ / %@ দিন রোজা", "%@ / %@ दिन रोज़ा रखा", "ถือศีลอด %@ / %@ วัน"],
    "amelW.name": ["İbadet Takibi", "Worship Tracker", "متابعة العبادات", "Ibadat-Tracker", "Suivi des adorations", "Pelacak Ibadah", "عبادت ٹریکر", "Трекер поклонения", "Seguimiento de adoración", "Tracker delle ibadat", "Penjejak Ibadah", "ইবাদত ট্র্যাকার", "इबादत ट्रैकर", "ติดตามอิบาดะฮ์"],
    "amelW.desc": ["Günlük ibadet kayıtları.", "Daily worship logs.", "سجلات العبادة اليومية.", "Tägliche Ibadat-Einträge.", "Vos adorations quotidiennes.", "Catatan ibadah harian.", "روزانہ کی عبادات۔", "Ежедневные поклонения.", "Registros diarios de adoración.", "Registri giornalieri delle ibadat.", "Catatan ibadah harian.", "দৈনিক ইবাদতের তালিকা।", "रोज़ाना की इबादत का रिकॉर्ड।", "บันทึกอิบาดะฮ์รายวัน"],

    "insp.verse": ["Günün ayeti", "Verse of the day", "آية اليوم", "Vers des Tages", "Verset du jour", "Ayat hari ini", "آج کی آیت", "Аят дня", "Versículo del día", "Versetto del giorno", "Ayat hari ini", "আজকের আয়াত", "आज की आयत", "อายะฮ์ประจำวัน"],
    "insp.hadith": ["Günün hadisi", "Hadith of the day", "حديث اليوم", "Hadith des Tages", "Hadith du jour", "Hadis hari ini", "آج کی حدیث", "Хадис дня", "Hadiz del día", "Hadith del giorno", "Hadis hari ini", "আজকের হাদীস", "आज की हदीस", "หะดีษประจำวัน"],
    "insp.loading": ["Yükleniyor…", "Loading…", "جارٍ التحميل…", "Wird geladen…", "Chargement…", "Memuat…", "لوڈ ہو رہا ہے…", "Загрузка…", "Cargando…", "Caricamento…", "Memuatkan…", "লোড হচ্ছে…", "लोड हो रहा है…", "กำลังโหลด…"],
    "insp.fallback": ["Günün ilhamı", "Daily inspiration", "إلهام اليوم", "Tägliche Inspiration", "Inspiration du jour", "Inspirasi harian", "روزانہ کی تحریک", "Вдохновение дня", "Inspiración diaria", "Ispirazione quotidiana", "Inspirasi harian", "দৈনিক অনুপ্রেরণা", "रोज़ाना की प्रेरणा", "แรงบันดาลใจประจำวัน"],
    "insp.name": ["Günün Hadisi / Ayeti", "Hadith / Verse of the Day", "حديث / آية اليوم", "Hadith / Vers des Tages", "Hadith / Verset du jour", "Hadis / Ayat Hari Ini", "آج کی حدیث / آیت", "Хадис / аят дня", "Hadiz / Versículo del día", "Hadith / Versetto del giorno", "Hadis / Ayat Hari Ini", "আজকের হাদীস / আয়াত", "आज की हदीस / आयत", "หะดีษ / อายะฮ์ประจำวัน"],
    "insp.desc": ["Günün ayeti ya da hadisi, kilit ekranında da.", "The verse or hadith of the day, also on the lock screen.", "آية أو حديث اليوم، على شاشة القفل أيضًا.", "Der Vers oder Hadith des Tages, auch auf dem Sperrbildschirm.", "Le verset ou hadith du jour, aussi sur l'écran verrouillé.", "Ayat atau hadis hari ini, juga di layar kunci.", "آج کی آیت یا حدیث، لاک اسکرین پر بھی۔", "Аят или хадис дня, также на экране блокировки.", "El versículo o hadiz del día, también en la pantalla de bloqueo.", "Il versetto o hadith del giorno, anche nella schermata di blocco.", "Ayat atau hadis hari ini, juga pada skrin kunci.", "আজকের আয়াত বা হাদীস, লক স্ক্রিনেও।", "आज की आयत या हदीस, लॉक स्क्रीन पर भी।", "อายะฮ์หรือหะดีษประจำวัน แสดงบนหน้าจอล็อกได้ด้วย"],
    "dr.name": ["Günün okuması", "Daily reading", "قراءة اليوم", "Tageslektüre", "Lecture du jour", "Bacaan hari ini", "آج کا مطالعہ", "Чтение дня", "Lectura diaria", "Lettura quotidiana", "Bacaan harian", "দৈনিক পাঠ", "दैनिक पाठ", "อ่านประจำวัน"],
    "dr.esma": ["Günün esması", "Name of the day", "اسم اليوم", "Name des Tages", "Nom du jour", "Nama hari ini", "آج کا اسم", "Имя дня", "Nombre del día", "Nome del giorno", "Asmaul Husna hari ini", "আজকের নাম", "आज का नाम", "พระนามประจำวัน"],
    "dr.dua": ["Günün duası", "Dua of the day", "دعاء اليوم", "Bittgebet des Tages", "Invocation du jour", "Doa hari ini", "آج کی دعا", "Дуа дня", "Dua del día", "Dua del giorno", "Doa hari ini", "আজকের দোয়া", "आज की दुआ", "ดุอาอ์ประจำวัน"],
    "dr.desc": ["Günün esması, ayeti ve duası.", "The name, verse and prayer of the day.", "اسم اليوم وآيته ودعاؤه.", "Name, Vers und Bittgebet des Tages.", "Le nom, le verset et l'invocation du jour.", "Nama, ayat, dan doa hari ini.", "آج کا اسم، آیت اور دعا۔", "Имя, аят и дуа дня.", "El nombre, la aleya y la súplica del día.", "Il nome, il versetto e la supplica del giorno.", "Nama, ayat dan doa hari ini.", "আজকের নাম, আয়াত ও দোয়া।", "आज का नाम, आयत और दुआ।", "พระนาม อายะฮ์ และดุอาอ์ประจำวัน"],
    "dr.empty": ["Günün okuması için uygulamayı açın", "Open the app for today's reading", "افتح التطبيق لقراءة اليوم", "Öffne die App für die Lesung des Tages", "Ouvrez l'app pour la lecture du jour", "Buka aplikasi untuk bacaan hari ini", "آج کی تلاوت کے لیے ایپ کھولیں", "Откройте приложение для чтения дня", "Abre la app para la lectura del día", "Apri l'app per la lettura del giorno", "Buka aplikasi untuk bacaan hari ini", "আজকের পাঠের জন্য অ্যাপ খুলুন", "आज के पाठ के लिए ऐप खोलें", "เปิดแอปเพื่ออ่านประจำวัน"],

    "times.current.name": ["Namaz Vakti", "Prayer Time", "وقت الصلاة", "Gebetszeit", "Heure de prière", "Waktu Salat", "نماز کا وقت", "Время намаза", "Hora de oración", "Orario di preghiera", "Waktu Solat", "নামাজের ওয়াক্ত", "नमाज़ का वक़्त", "เวลาละหมาด"],
    "times.current.desc": ["İçinde bulunulan vakit ve kalan süre.", "The current prayer time and time remaining.", "الوقت الحالي والمدة المتبقية.", "Die aktuelle Gebetszeit und die verbleibende Zeit.", "L'heure de prière en cours et le temps restant.", "Waktu salat saat ini dan sisa waktunya.", "موجودہ نماز کا وقت اور باقی وقت۔", "Текущее время намаза и сколько осталось.", "La hora de oración actual y el tiempo restante.", "L'orario di preghiera attuale e il tempo rimasto.", "Waktu solat semasa dan baki masa.", "বর্তমান ওয়াক্ত ও বাকি সময়।", "मौजूदा नमाज़ का वक़्त और बचा समय।", "เวลาละหมาดปัจจุบันและเวลาที่เหลือ"],
    "times.list.name": ["Namaz Vakitleri", "Prayer Times", "مواقيت الصلاة", "Gebetszeiten", "Horaires de prière", "Waktu Salat", "نماز کے اوقات", "Время намазов", "Horarios de oración", "Orari di preghiera", "Waktu Solat", "নামাজের সময়সূচি", "नमाज़ के समय", "เวลาละหมาด"],
    "times.list.desc": ["Günün namaz vakitleri.", "Today's prayer times.", "مواقيت صلاة اليوم.", "Die heutigen Gebetszeiten.", "Les horaires de prière du jour.", "Waktu salat hari ini.", "آج کے نماز کے اوقات۔", "Время намазов на сегодня.", "Los horarios de oración de hoy.", "Gli orari di preghiera di oggi.", "Waktu solat hari ini.", "আজকের নামাজের সময়।", "आज की नमाज़ के समय।", "เวลาละหมาดของวันนี้"],

    "standby.name": ["Salah · Büyük saat", "Salah · Large clock", "Salah · ساعة كبيرة", "Salah · Große Uhr", "Salah · Grande horloge", "Salah · Jam besar", "Salah · بڑی گھڑی", "Salah · Большие часы", "Salah · Reloj grande", "Salah · Orologio grande", "Salah · Jam besar", "Salah · বড় ঘড়ি", "Salah · बड़ी घड़ी", "Salah · นาฬิกาขนาดใหญ่"],
    "standby.desc": [
      "Standby modu için büyük namaz vakti sayacı. iPhone şarjda ve yatay duruyorken görünür.",
      "A large prayer countdown for StandBy. Shown while iPhone is charging in landscape.",
      "عدّاد كبير لوقت الصلاة لوضع الاستعداد. يظهر أثناء شحن iPhone بالوضع الأفقي.",
    ],
    "control.mark": ["Kıldım", "Prayed", "صلّيت", "Gebetet", "Prié", "Sudah salat", "نماز پڑھ لی", "Совершил", "Recé", "Ho pregato", "Sudah solat", "পড়েছি", "पढ़ ली", "ละหมาดแล้ว"],
    "control.markName": ["Namazı işaretle", "Mark prayer", "تسجيل الصلاة", "Gebet markieren", "Marquer la prière", "Tandai salat", "نماز درج کریں", "Отметить намаз", "Marcar oración", "Segna preghiera", "Tandakan solat", "নামাজ চিহ্নিত করুন", "नमाज़ दर्ज करें", "ทำเครื่องหมายละหมาด"],
    "control.markDesc": ["O anki vakti kıldım olarak işaretler.", "Marks the current prayer as prayed.", "يسجّل الصلاة الحالية كمؤدّاة.", "Markiert das aktuelle Gebet als verrichtet.", "Marque la prière en cours comme accomplie.", "Menandai salat saat ini sudah dikerjakan.", "موجودہ نماز کو ادا شدہ درج کرتا ہے۔", "Отмечает текущий намаз как совершённый.", "Marca la oración actual como realizada.", "Segna la preghiera corrente come eseguita.", "Menandakan solat semasa sudah dikerjakan.", "বর্তমান নামাজ আদায় হয়েছে বলে চিহ্নিত করে।", "मौजूदा नमाज़ को अदा की हुई दर्ज करता है।", "ทำเครื่องหมายว่าละหมาดปัจจุบันเสร็จแล้ว"],
    "control.prayed": ["%@ kılındı", "%@ prayed", "تمت صلاة %@", "%@ gebetet", "%@ accomplie", "%@ sudah dikerjakan", "%@ ادا ہو گئی", "%@ совершён", "%@ realizada", "%@ eseguita", "%@ sudah dikerjakan", "%@ আদায়", "%@ अदा की", "%@ ละหมาดแล้ว"],
    "control.noPrayer": ["Vakit bekleniyor", "Waiting for prayer time", "بانتظار وقت الصلاة", "Warten auf Gebetszeit", "En attente de l'heure de prière", "Menunggu waktu salat", "نماز کے وقت کا انتظار", "Ожидание времени намаза", "Esperando la hora de oración", "In attesa dell'orario di preghiera", "Menunggu waktu solat", "নামাজের ওয়াক্তের অপেক্ষা", "नमाज़ के वक़्त का इंतज़ार", "รอเวลาละหมาด"],
    "control.dhikrName": ["Zikirmatik", "Dhikr counter", "المسبحة", "Dhikr-Zähler", "Compteur de dhikr", "Penghitung zikir", "ذکر کاؤنٹر", "Счётчик зикра", "Contador de dhikr", "Contatore di dhikr", "Pembilang zikir", "জিকির কাউন্টার", "ज़िक्र काउंटर", "ตัวนับซิกิร"],
    "control.dhikrDesc": ["Her dokunuşta bir zikir sayar.", "Counts one dhikr with each tap.", "يعدّ ذكرًا واحدًا مع كل لمسة.", "Zählt mit jedem Tippen einen Dhikr.", "Compte un dhikr à chaque toucher.", "Menghitung satu zikir setiap ketukan.", "ہر ٹیپ پر ایک ذکر گنتا ہے۔", "Считает один зикр при каждом нажатии.", "Cuenta un dhikr con cada toque.", "Conta un dhikr a ogni tocco.", "Mengira satu zikir setiap ketikan.", "প্রতি ট্যাপে একটি জিকির গোনে।", "हर टैप पर एक ज़िक्र गिनता है।", "นับซิกิรหนึ่งครั้งทุกครั้งที่แตะ"],
    "premium.cta": ["Premium'a geç", "Go Premium", "اشترك في بريميوم", "Premium holen", "Passer à Premium", "Beralih ke Premium", "پریمیم لیں", "Перейти на Premium", "Hazte Premium", "Passa a Premium", "Dapatkan Premium", "প্রিমিয়াম নিন", "प्रीमियम लें", "อัปเกรดเป็นพรีเมียม"],

    "alarmW.open": ["Alarmlar", "Alarms", "المنبّهات", "Wecker", "Alarmes", "Alarm", "الارم", "Будильники", "Alarmas", "Sveglie", "Penggera", "অ্যালার্ম", "अलार्म", "นาฬิกาปลุก"],
    "alarmW.next": ["Sıradaki alarm %@", "Next alarm %@", "المنبّه التالي %@", "Nächster Wecker %@", "Prochaine alarme %@", "Alarm berikutnya %@", "اگلا الارم %@", "Следующий будильник %@", "Próxima alarma %@", "Prossima sveglia %@", "Penggera seterusnya %@", "পরবর্তী অ্যালার্ম %@", "अगला अलार्म %@", "ปลุกครั้งถัดไป %@"],

    "ring.name": ["Gün Çemberi", "Day Circle", "دائرة اليوم", "Tageskreis", "Cercle du jour", "Lingkaran Hari", "دن کا دائرہ", "Круг дня", "Círculo del día", "Cerchio del giorno", "Bulatan Hari", "দিনের বৃত্ত", "दिन का चक्र", "วงกลมประจำวัน"],
    "ring.desc": [
      "Günün vakitleri ve kerahat vakitleri tek çemberde.",
      "Today's prayer and makruh times in one circle.",
      "مواقيت اليوم وأوقات الكراهة في دائرة واحدة.",
    ],
    "ring.forbidden": ["Kerahat", "Makruh", "كراهة", "Makruh", "Makruh", "Makruh", "مکروہ", "Макрух", "Makruh", "Makruh", "Makruh", "মাকরুহ", "मकरूह", "มักรูห์"],
  ]
}
