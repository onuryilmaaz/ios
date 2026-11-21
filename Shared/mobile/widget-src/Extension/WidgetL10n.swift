import Foundation

/// Widget ve Live Activity metinleri. Dil, uygulamanın App Group'a yazdığı
/// `appLanguage` değeridir (`languages`); yoksa Türkçe.
///
/// Vakit adları paylaşılan veride kanonik Türkçe durur ("Öğle"); yalnız
/// gösterirken `WL.prayer(_:)` ile çevrilir.
enum WL {
  /// Sütun sırası: tr, en, ar, de, fr, id, ur, bs, ru.
  static let languages = ["tr", "en", "ar", "de", "fr", "id", "ur", "bs", "ru"]

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
    "prayer.imsak": ["İmsak", "Imsak", "الإمساك", "Imsak", "Imsak", "Imsak", "امساک", "Imsak", "Имсак"],
    "prayer.sabah": ["Sabah", "Fajr", "الفجر", "Fadschr", "Fajr", "Subuh", "فجر", "Sabah", "Фаджр"],
    "prayer.gunes": ["Güneş", "Sunrise", "الشروق", "Schuruq", "Lever du soleil", "Terbit", "طلوع آفتاب", "Izlazak sunca", "Восход"],
    "prayer.ogle": ["Öğle", "Dhuhr", "الظهر", "Dhuhr", "Dhuhr", "Zuhur", "ظہر", "Podne", "Зухр"],
    "prayer.ikindi": ["İkindi", "Asr", "العصر", "Asr", "Asr", "Asar", "عصر", "Ikindija", "Аср"],
    "prayer.aksam": ["Akşam", "Maghrib", "المغرب", "Maghrib", "Maghrib", "Magrib", "مغرب", "Akšam", "Магриб"],
    "prayer.yatsi": ["Yatsı", "Isha", "العشاء", "Ischa", "Isha", "Isya", "عشاء", "Jacija", "Иша"],

    "amel.quran": ["Kur'an", "Qur'an", "القرآن", "Koran", "Coran", "Al-Qur'an", "قرآن", "Kur'an", "Коран"],
    "amel.nafile": ["Nafile", "Nafl", "النوافل", "Nafila", "Nafila", "Sunah", "نفل", "Nafila", "Нафиля"],
    "amel.fasting": ["Oruç", "Fasting", "الصيام", "Fasten", "Jeûne", "Puasa", "روزہ", "Post", "Пост"],
    "amel.sadaka": ["Sadaka", "Charity", "الصدقة", "Spende", "Aumône", "Sedekah", "صدقہ", "Sadaka", "Садака"],
    "amel.dua": ["Dua", "Dua", "الدعاء", "Dua", "Dua", "Doa", "دعا", "Dova", "Дуа"],
    "amel.memorization": ["Ezber", "Memorization", "الحفظ", "Auswendiglernen", "Mémorisation", "Hafalan", "حفظ", "Hifz", "Заучивание"],
    "amel.book": ["Kitap", "Book", "كتاب", "Buch", "Livre", "Buku", "کتاب", "Knjiga", "Книга"],

    "window.untilEnd": ["%@ vaktinin çıkmasına", "Until %@ ends", "حتى خروج وقت %@", "Bis %@ endet", "Jusqu'à la fin de %@", "Hingga %@ berakhir", "%@ ختم ہونے تک", "Do kraja: %@", "До конца: %@"],
    "window.until": ["%@ vaktine", "Until %@", "حتى %@", "Bis %@", "Jusqu'à %@", "Menuju %@", "%@ تک", "Do: %@", "До: %@"],
    "window.ends": ["Çıkış %@", "Ends %@", "ينتهي %@", "Endet %@", "Fin %@", "Berakhir %@", "ختم %@", "Završava %@", "Конец %@"],
    "window.starts": ["Giriş %@", "Starts %@", "يبدأ %@", "Beginnt %@", "Début %@", "Mulai %@", "شروع %@", "Počinje %@", "Начало %@"],
    "window.startsLabel": ["Giriş", "Starts", "يبدأ", "Beginnt", "Début", "Mulai", "شروع", "Počinje", "Начало"],
    "window.entered": ["Vakti girdi", "Time has begun", "دخل الوقت", "Die Gebetszeit hat begonnen", "L'heure a commencé", "Waktu telah masuk", "وقت شروع ہو گیا", "Vakat je nastupio", "Время наступило"],
    "window.over": ["Vakit çıktı", "Time is over", "خرج الوقت", "Die Zeit ist vorbei", "L'heure est passée", "Waktu telah habis", "وقت ختم ہو گیا", "Vakat je istekao", "Время истекло"],
    "window.openApp": ["Vakitler için uygulamayı açın", "Open the app for prayer times", "افتح التطبيق لعرض المواقيت", "Öffne die App für die Gebetszeiten", "Ouvrez l'app pour les horaires de prière", "Buka aplikasi untuk waktu salat", "نماز کے اوقات کے لیے ایپ کھولیں", "Otvorite aplikaciju za vaktove", "Откройте приложение для времени намазов"],
    "window.waiting": ["Vakit bekleniyor", "Waiting for prayer time", "في انتظار الوقت", "Warten auf die Gebetszeit", "En attente de l'heure de prière", "Menunggu waktu salat", "نماز کے وقت کا انتظار", "Čeka se vakat", "Ожидание времени намаза"],
    "window.none": ["Vakit yok", "No prayer time", "لا يوجد وقت", "Keine Gebetszeit", "Aucune heure de prière", "Tidak ada waktu salat", "نماز کا وقت نہیں", "Nema vakta", "Нет времени намаза"],
    "window.now": ["Şimdi", "Now", "الآن", "Jetzt", "Maintenant", "Sekarang", "ابھی", "Sada", "Сейчас"],
    "window.nowLower": ["şimdi", "now", "الآن", "jetzt", "maintenant", "sekarang", "ابھی", "sada", "сейчас"],
    "window.prayed": ["kılındı", "prayed", "صُلّيت", "gebetet", "accomplie", "sudah salat", "ادا کی", "klanjano", "совершён"],

    "tracker.eyebrow": ["Namaz", "Prayer", "الصلاة", "Gebet", "Prière", "Salat", "نماز", "Namaz", "Намаз"],
    "tracker.title": ["Namaz Takibi", "Prayer Tracker", "متابعة الصلاة", "Gebetstracker", "Suivi des prières", "Pelacak Salat", "نماز ٹریکر", "Praćenje namaza", "Трекер намазов"],
    "tracker.allDone": ["Bugün tamamlandı", "Done for today", "اكتملت اليوم", "Für heute erledigt", "Terminé pour aujourd'hui", "Selesai untuk hari ini", "آج کے لیے مکمل", "Gotovo za danas", "На сегодня всё"],
    "tracker.allPending": ["5 vakit bekliyor", "5 prayers pending", "5 صلوات متبقية", "5 Gebete offen", "5 prières en attente", "5 salat tertunda", "5 نمازیں باقی", "5 namaza na čekanju", "5 намазов впереди"],
    "tracker.left": ["%@ vakit kaldı", "%@ prayers left", "بقيت %@ صلوات", "%@ Gebete offen", "Encore %@ prières", "%@ salat lagi", "%@ نمازیں باقی", "Preostalo namaza: %@", "Осталось намазов: %@"],
    "tracker.markHint": ["Kıldım olarak işaretlemek için dokunun", "Tap to mark as prayed", "اضغط للتعليم كمُصلّاة", "Tippen, um als gebetet zu markieren", "Touchez pour marquer comme accomplie", "Ketuk untuk menandai sudah salat", "ادا شدہ درج کرنے کے لیے ٹیپ کریں", "Dodirnite za označavanje", "Нажмите, чтобы отметить"],
    "tracker.kaza": ["kaza olarak kılındı", "made up (qada)", "قُضيت", "nachgeholt (Qada)", "rattrapée (qada)", "sudah diqada", "قضا ادا کی", "naklanjano (kada)", "возмещён (каза)"],
    "tracker.done": ["kılındı", "prayed", "صُلّيت", "gebetet", "accomplie", "sudah salat", "ادا کی", "klanjano", "совершён"],
    "tracker.notDone": ["kılınmadı", "not prayed", "لم تُصلَّ", "nicht gebetet", "non accomplie", "belum salat", "ادا نہیں کی", "nije klanjano", "не совершён"],
    "tracker.notYet": ["vakti girmedi", "not yet time", "لم يدخل وقتها", "noch nicht Zeit", "pas encore l'heure", "belum waktunya", "ابھی وقت نہیں ہوا", "još nije vakat", "время не наступило"],
    "tracker.desc.small": ["Bugün kılınan namazların özeti.", "Summary of today's prayers.", "ملخص صلوات اليوم.", "Übersicht der heutigen Gebete.", "Résumé des prières du jour.", "Ringkasan salat hari ini.", "آج کی نمازوں کا خلاصہ۔", "Sažetak današnjih namaza.", "Итоги намазов за сегодня."],
    "tracker.desc.large": ["Günlük namaz takip durumu.", "Daily prayer tracking status.", "حالة متابعة الصلاة اليومية.", "Täglicher Stand deiner Gebete.", "Suivi quotidien des prières.", "Status pelacakan salat harian.", "روزانہ نماز کے ریکارڈ کی صورتحال۔", "Dnevno praćenje namaza.", "Ежедневный учёт намазов."],

    "amelW.eyebrow": ["İbadet", "Worship", "العبادة", "Gottesdienst", "Adoration", "Ibadah", "عبادت", "Ibadet", "Поклонение"],
    "amelW.title": ["Bugünün İbadetleri", "Today's Worship", "عبادات اليوم", "Heutige Ibadat", "Adorations du jour", "Ibadah Hari Ini", "آج کی عبادات", "Današnji ibadeti", "Поклонения за сегодня"],
    "amelW.none": ["Bugün kayıt yok", "Nothing logged today", "لا سجلات اليوم", "Heute nichts eingetragen", "Rien de noté aujourd'hui", "Belum ada catatan hari ini", "آج کچھ درج نہیں", "Danas ništa nije zabilježeno", "Сегодня ничего не отмечено"],
    "amelW.count": ["kayıt · %@ tür", "logged · %@ types", "مسجّل · %@ أنواع", "eingetragen · %@ Arten", "noté · %@ types", "tercatat · %@ jenis", "درج · %@ اقسام", "zabilježeno · vrsta: %@", "отмечено · видов: %@"],
    "amelW.logged": ["bugün kaydedildi", "logged today", "سُجّل اليوم", "heute eingetragen", "noté aujourd'hui", "tercatat hari ini", "آج درج", "zabilježeno danas", "отмечено сегодня"],
    "amelW.notLogged": ["kayıt yok", "not logged", "غير مسجّل", "nicht eingetragen", "non noté", "belum dicatat", "درج نہیں", "nije zabilježeno", "не отмечено"],
    "ramadanW.fast.name": ["Oruç", "Fasting", "الصيام", "Fasten", "Jeûne", "Puasa", "روزہ", "Post", "Пост"],
    "ramadanW.fast.desc": ["Günün sayacı ve Ramazan oruçların.", "Today's countdown and your Ramadan fasts.", "عدّاد اليوم وصيامك في رمضان.", "Countdown für heute und deine Ramadan-Fastentage.", "Le compte à rebours du jour et vos jeûnes du Ramadan.", "Hitung mundur hari ini dan puasa Ramadan Anda.", "آج کی الٹی گنتی اور آپ کے رمضان کے روزے۔", "Današnje odbrojavanje i vaši ramazanski postovi.", "Обратный отсчёт на сегодня и ваши посты в Рамадан."],
    "ramadanW.table.name": ["İmsakiye", "Ramadan Timetable", "إمساكية رمضان", "Ramadan-Zeitplan", "Calendrier du Ramadan", "Jadwal Ramadan", "رمضان کا نظام الاوقات", "Ramazanska vaktija", "Расписание Рамадана"],
    "dhikrW.name": ["Zikirmatik", "Dhikr Counter", "المسبحة", "Dhikr-Zähler", "Compteur de dhikr", "Penghitung Zikir", "ذکر کاؤنٹر", "Brojač zikra", "Счётчик зикра"],
    "goalsW.name": ["Hedeflerim", "My goals", "أهدافي", "Meine Ziele", "Mes objectifs", "Target saya", "میرے اہداف", "Moji ciljevi", "Мои цели"],
    "goalsW.desc": ["Kaza borcu, bugünkü ezber tekrarı ve teheccüd.", "Make-up prayers, today's memorization review and tahajjud.", "الصلوات الفائتة ومراجعة الحفظ اليوم والتهجد.", "Nachzuholende Gebete, heutige Wiederholung und Tahadschud.", "Prières à rattraper, révision du jour et tahajjud.", "Salat qada, murajaah hafalan hari ini, dan tahajud.", "قضا نمازیں، آج کا حفظ کا دہرانا اور تہجد۔", "Kada namazi, današnje ponavljanje hifza i tehadžud.", "Каза-намазы, повторение на сегодня и тахаджуд."],
    "goalsW.kaza": ["Kaza borcu", "Make-up", "القضاء", "Nachholen", "Rattrapage", "Qada", "قضا", "Kada", "Каза"],
    "goalsW.kazaDetail": ["vakit kaldı", "prayers left", "صلاة متبقية", "Gebete offen", "prières restantes", "salat tersisa", "نمازیں باقی", "preostalo namaza", "намазов осталось"],
    "goalsW.hifz": ["Ezber tekrarı", "Review", "المراجعة", "Wiederholung", "Révision", "Murajaah", "دہرائی", "Ponavljanje", "Повторение"],
    "goalsW.hifzDetail": ["ayet bugün", "verses today", "آية اليوم", "Verse heute", "versets aujourd'hui", "ayat hari ini", "آج کی آیات", "ajeta danas", "аятов сегодня"],
    "goalsW.hifzDone": ["bugünlük tamam", "done for today", "انتهت اليوم", "für heute erledigt", "terminé pour aujourd'hui", "selesai hari ini", "آج کے لیے مکمل", "gotovo za danas", "на сегодня готово"],
    "goalsW.hifzEmpty": ["ezber ekle", "add verses", "أضف آيات", "Verse hinzufügen", "ajouter des versets", "tambah ayat", "آیات شامل کریں", "dodaj ajete", "добавьте аяты"],
    "goalsW.teheccud": ["Teheccüd", "Tahajjud", "التهجد", "Tahadschud", "Tahajjud", "Tahajud", "تہجد", "Tehadžud", "Тахаджуд"],
    "goalsW.done": ["Kılındı", "Prayed", "صُلّيت", "Gebetet", "Accompli", "Dikerjakan", "ادا کی", "Klanjano", "Совершён"],
    "goalsW.notYet": ["Henüz değil", "Not yet", "ليس بعد", "Noch nicht", "Pas encore", "Belum", "ابھی نہیں", "Još ne", "Ещё нет"],
    "goalsW.month": ["bu ay %@ gece", "%@ nights this month", "%@ ليلة هذا الشهر", "%@ Nächte diesen Monat", "%@ nuits ce mois-ci", "%@ malam bulan ini", "اس مہینے %@ راتیں", "%@ noći ovog mjeseca", "Ночей в этом месяце: %@"],
    "dhikrW.desc": ["Ana ekrandan dokunarak zikir ve tesbihat çek.", "Count dhikr and tasbih right from your Home Screen.", "سبّح واذكر من الشاشة الرئيسية بلمسة.", "Zähle Dhikr und Tasbih direkt vom Home-Bildschirm.", "Comptez dhikr et tasbih depuis l'écran d'accueil.", "Hitung zikir dan tasbih langsung dari layar utama.", "ہوم اسکرین سے ہی ذکر اور تسبیح گنیں۔", "Brojite zikr i tesbih direktno s početnog ekrana.", "Считайте зикр и тасбих прямо с главного экрана."],
    "dhikrW.eyebrow": ["Zikir", "Dhikr", "الذكر", "Dhikr", "Dhikr", "Zikir", "ذکر", "Zikr", "Зикр"],
    "dhikrW.tesbihat": ["Tesbihat", "Tasbih", "التسبيح", "Tasbih", "Tasbih", "Tasbih", "تسبیح", "Tesbih", "Тасбих"],
    "dhikrW.done": ["Tesbihat tamamlandı", "Tasbih complete", "اكتمل التسبيح", "Tasbih abgeschlossen", "Tasbih terminé", "Tasbih selesai", "تسبیح مکمل", "Tesbih završen", "Тасбих завершён"],
    "dhikrW.again": ["Yeniden başla", "Start again", "ابدأ من جديد", "Neu beginnen", "Recommencer", "Mulai lagi", "دوبارہ شروع کریں", "Počni ponovo", "Начать снова"],
    "dhikrW.today": ["Bugün %@", "Today %@", "اليوم %@", "Heute %@", "Aujourd'hui %@", "Hari ini %@", "آج %@", "Danas %@", "Сегодня %@"],
    "dhikrW.undo": ["Geri al", "Undo", "تراجع", "Rückgängig", "Annuler", "Urungkan", "واپس", "Poništi", "Отменить"],
    "dhikrW.tapA11y": ["%@, %@. Saymak için dokun", "%@, %@. Tap to count", "%@، %@. اضغط للعد", "%@, %@. Tippen zum Zählen", "%@, %@. Touchez pour compter", "%@, %@. Ketuk untuk menghitung", "%@، %@۔ گننے کے لیے ٹیپ کریں", "%@, %@. Dodirnite za brojanje", "%@, %@. Нажмите, чтобы считать"],
    "dhikrW.subhanallah": ["Sübhânallâh", "Subhanallah", "سبحان الله", "Subhanallah", "Subhanallah", "Subhanallah", "سبحان اللہ", "Subhanallah", "Субханаллах"],
    "dhikrW.elhamdulillah": ["Elhamdülillâh", "Alhamdulillah", "الحمد لله", "Alhamdulillah", "Alhamdulillah", "Alhamdulillah", "الحمد للہ", "Elhamdulillah", "Альхамдулиллях"],
    "dhikrW.allahuekber": ["Allâhü ekber", "Allahu akbar", "الله أكبر", "Allahu akbar", "Allahu akbar", "Allahu akbar", "اللہ اکبر", "Allahu ekber", "Аллаху акбар"],
    "dhikrW.tehlil": ["Lâ ilâhe illallâh", "La ilaha illallah", "لا إله إلا الله", "La ilaha illallah", "La ilaha illallah", "La ilaha illallah", "لا الٰہ الا اللہ", "La ilahe illallah", "Ля иляха илляллах"],
    "dhikrW.istigfar": ["Estağfirullâh", "Astaghfirullah", "أستغفر الله", "Astaghfirullah", "Astaghfirullah", "Astagfirullah", "استغفر اللہ", "Estagfirullah", "Астагфируллах"],
    "dhikrW.salavat": ["Salavat", "Salawat", "الصلاة على النبي", "Salawat", "Salawat", "Selawat", "درود", "Salavat", "Салават"],
    "dhikrW.tesbihatClosing": ["Tehlil", "Tahlil", "التهليل", "Tahlil", "Tahlil", "Tahlil", "تہلیل", "Tehlil", "Тахлиль"],
    "ramadanW.table.desc": ["Önümüzdeki günlerin imsak ve iftar saatleri.", "Imsak and iftar times for the coming days.", "مواعيد الإمساك والإفطار للأيام القادمة.", "Imsak- und Iftarzeiten der kommenden Tage.", "Horaires d'imsak et d'iftar des prochains jours.", "Waktu imsak dan berbuka untuk hari-hari mendatang.", "آنے والے دنوں کے سحری اور افطار کے اوقات۔", "Vremena sehura i iftara za naredne dane.", "Время имсака и ифтара на ближайшие дни."],
    "ramadanW.lock.name": ["Ramazan", "Ramadan", "رمضان", "Ramadan", "Ramadan", "Ramadan", "رمضان", "Ramazan", "Рамадан"],
    "ramadanW.lock.desc": ["İftar sayacı ve oruç sayın kilit ekranında.", "Iftar countdown and fasts on the lock screen.", "عدّاد الإفطار وصيامك على شاشة القفل.", "Iftar-Countdown und Fastentage auf dem Sperrbildschirm.", "Compte à rebours de l'iftar et jeûnes sur l'écran verrouillé.", "Hitung mundur berbuka dan puasa di layar kunci.", "لاک اسکرین پر افطار کی الٹی گنتی اور روزے۔", "Odbrojavanje do iftara i postovi na zaključanom ekranu.", "Отсчёт до ифтара и посты на экране блокировки."],
    "ramadanW.empty": ["Ramazan'da burada olacak", "Appears here during Ramadan", "يظهر هنا في رمضان", "Erscheint hier im Ramadan", "Apparaît ici pendant le Ramadan", "Muncul di sini selama Ramadan", "رمضان میں یہاں نظر آتا ہے", "Pojavljuje se ovdje tokom ramazana", "Появится здесь в Рамадан"],
    "ramadanW.day": ["%@. gün", "Day %@", "اليوم %@", "Tag %@", "Jour %@", "Hari ke-%@", "دن %@", "Dan %@", "День %@"],
    "ramadanW.untilIftar": ["İftara kalan", "Until iftar", "حتى الإفطار", "Bis Iftar", "Jusqu'à l'iftar", "Menuju berbuka", "افطار تک", "Do iftara", "До ифтара"],
    "ramadanW.untilSahur": ["Sahura kalan", "Until suhoor", "حتى السحور", "Bis Sahur", "Jusqu'au suhur", "Menuju sahur", "سحری تک", "Do sehura", "До сухура"],
    "ramadanW.iftar": ["İftar", "Iftar", "الإفطار", "Iftar", "Iftar", "Berbuka", "افطار", "Iftar", "Ифтар"],
    "ramadanW.sahur": ["Sahur", "Suhoor", "السحور", "Sahur", "Suhur", "Sahur", "سحری", "Sehur", "Сухур"],
    "ramadanW.imsak": ["İmsak", "Imsak", "الإمساك", "Imsak", "Imsak", "Imsak", "امساک", "Imsak", "Имсак"],
    "ramadanW.count": ["%@ / %@ gün oruç", "%@ / %@ days fasted", "%@ / %@ يوم صيام", "%@ / %@ Tage gefastet", "%@ / %@ jours jeûnés", "%@ / %@ hari berpuasa", "%@ / %@ دن روزہ رکھا", "%@ / %@ dana posta", "%@ / %@ дней поста"],
    "amelW.name": ["İbadet Takibi", "Worship Tracker", "متابعة العبادات", "Ibadat-Tracker", "Suivi des adorations", "Pelacak Ibadah", "عبادت ٹریکر", "Praćenje ibadeta", "Трекер поклонения"],
    "amelW.desc": ["Günlük ibadet kayıtları.", "Daily worship logs.", "سجلات العبادة اليومية.", "Tägliche Ibadat-Einträge.", "Vos adorations quotidiennes.", "Catatan ibadah harian.", "روزانہ کی عبادات۔", "Dnevni ibadeti.", "Ежедневные поклонения."],

    "insp.verse": ["Günün ayeti", "Verse of the day", "آية اليوم", "Vers des Tages", "Verset du jour", "Ayat hari ini", "آج کی آیت", "Ajet dana", "Аят дня"],
    "insp.hadith": ["Günün hadisi", "Hadith of the day", "حديث اليوم", "Hadith des Tages", "Hadith du jour", "Hadis hari ini", "آج کی حدیث", "Hadis dana", "Хадис дня"],
    "insp.loading": ["Yükleniyor…", "Loading…", "جارٍ التحميل…", "Wird geladen…", "Chargement…", "Memuat…", "لوڈ ہو رہا ہے…", "Učitavanje…", "Загрузка…"],
    "insp.fallback": ["Günün ilhamı", "Daily inspiration", "إلهام اليوم", "Tägliche Inspiration", "Inspiration du jour", "Inspirasi harian", "روزانہ کی تحریک", "Dnevna inspiracija", "Вдохновение дня"],
    "insp.name": ["Günün Hadisi / Ayeti", "Hadith / Verse of the Day", "حديث / آية اليوم", "Hadith / Vers des Tages", "Hadith / Verset du jour", "Hadis / Ayat Hari Ini", "آج کی حدیث / آیت", "Hadis / Ajet dana", "Хадис / аят дня"],
    "insp.desc": ["Günün ayeti ya da hadisi, kilit ekranında da.", "The verse or hadith of the day, also on the lock screen.", "آية أو حديث اليوم، على شاشة القفل أيضًا.", "Der Vers oder Hadith des Tages, auch auf dem Sperrbildschirm.", "Le verset ou hadith du jour, aussi sur l'écran verrouillé.", "Ayat atau hadis hari ini, juga di layar kunci.", "آج کی آیت یا حدیث، لاک اسکرین پر بھی۔", "Ajet ili hadis dana, i na zaključanom ekranu.", "Аят или хадис дня, также на экране блокировки."],

    "times.current.name": ["Namaz Vakti", "Prayer Time", "وقت الصلاة", "Gebetszeit", "Heure de prière", "Waktu Salat", "نماز کا وقت", "Vakat", "Время намаза"],
    "times.current.desc": ["İçinde bulunulan vakit ve kalan süre.", "The current prayer time and time remaining.", "الوقت الحالي والمدة المتبقية.", "Die aktuelle Gebetszeit und die verbleibende Zeit.", "L'heure de prière en cours et le temps restant.", "Waktu salat saat ini dan sisa waktunya.", "موجودہ نماز کا وقت اور باقی وقت۔", "Trenutni vakat i preostalo vrijeme.", "Текущее время намаза и сколько осталось."],
    "times.list.name": ["Namaz Vakitleri", "Prayer Times", "مواقيت الصلاة", "Gebetszeiten", "Horaires de prière", "Waktu Salat", "نماز کے اوقات", "Vaktovi", "Время намазов"],
    "times.list.desc": ["Günün namaz vakitleri.", "Today's prayer times.", "مواقيت صلاة اليوم.", "Die heutigen Gebetszeiten.", "Les horaires de prière du jour.", "Waktu salat hari ini.", "آج کے نماز کے اوقات۔", "Današnji vaktovi.", "Время намазов на сегодня."],

    "standby.name": ["Salah · Büyük saat", "Salah · Large clock", "Salah · ساعة كبيرة", "Salah · Große Uhr", "Salah · Grande horloge", "Salah · Jam besar", "Salah · بڑی گھڑی", "Salah · Veliki sat", "Salah · Большие часы"],
    "standby.desc": [
      "Standby modu için büyük namaz vakti sayacı. iPhone şarjda ve yatay duruyorken görünür.",
      "A large prayer countdown for StandBy. Shown while iPhone is charging in landscape.",
      "عدّاد كبير لوقت الصلاة لوضع الاستعداد. يظهر أثناء شحن iPhone بالوضع الأفقي.",
    ],
    "control.mark": ["Kıldım", "Prayed", "صلّيت", "Gebetet", "Prié", "Sudah salat", "نماز پڑھ لی", "Klanjao sam", "Совершил"],
    "control.markName": ["Namazı işaretle", "Mark prayer", "تسجيل الصلاة", "Gebet markieren", "Marquer la prière", "Tandai salat", "نماز درج کریں", "Označi namaz", "Отметить намаз"],
    "control.markDesc": ["O anki vakti kıldım olarak işaretler.", "Marks the current prayer as prayed.", "يسجّل الصلاة الحالية كمؤدّاة.", "Markiert das aktuelle Gebet als verrichtet.", "Marque la prière en cours comme accomplie.", "Menandai salat saat ini sudah dikerjakan.", "موجودہ نماز کو ادا شدہ درج کرتا ہے۔", "Označava trenutni namaz kao klanjan.", "Отмечает текущий намаз как совершённый."],
    "control.prayed": ["%@ kılındı", "%@ prayed", "تمت صلاة %@", "%@ gebetet", "%@ accomplie", "%@ sudah dikerjakan", "%@ ادا ہو گئی", "%@ klanjan", "%@ совершён"],
    "control.noPrayer": ["Vakit bekleniyor", "Waiting for prayer time", "بانتظار وقت الصلاة", "Warten auf Gebetszeit", "En attente de l'heure de prière", "Menunggu waktu salat", "نماز کے وقت کا انتظار", "Čeka se vakat", "Ожидание времени намаза"],
    "control.dhikrName": ["Zikirmatik", "Dhikr counter", "المسبحة", "Dhikr-Zähler", "Compteur de dhikr", "Penghitung zikir", "ذکر کاؤنٹر", "Brojač zikra", "Счётчик зикра"],
    "control.dhikrDesc": ["Her dokunuşta bir zikir sayar.", "Counts one dhikr with each tap.", "يعدّ ذكرًا واحدًا مع كل لمسة.", "Zählt mit jedem Tippen einen Dhikr.", "Compte un dhikr à chaque toucher.", "Menghitung satu zikir setiap ketukan.", "ہر ٹیپ پر ایک ذکر گنتا ہے۔", "Broji jedan zikr pri svakom dodiru.", "Считает один зикр при каждом нажатии."],
    "premium.cta": ["Premium'a geç", "Go Premium", "اشترك في بريميوم", "Premium holen", "Passer à Premium", "Beralih ke Premium", "پریمیم لیں", "Pređi na Premium", "Перейти на Premium"],

    "alarmW.open": ["Alarmlar", "Alarms", "المنبّهات", "Wecker", "Alarmes", "Alarm", "الارم", "Alarmi", "Будильники"],
    "alarmW.next": ["Sıradaki alarm %@", "Next alarm %@", "المنبّه التالي %@", "Nächster Wecker %@", "Prochaine alarme %@", "Alarm berikutnya %@", "اگلا الارم %@", "Sljedeći alarm %@", "Следующий будильник %@"],

    "ring.name": ["Gün Çemberi", "Day Circle", "دائرة اليوم", "Tageskreis", "Cercle du jour", "Lingkaran Hari", "دن کا دائرہ", "Krug dana", "Круг дня"],
    "ring.desc": [
      "Günün vakitleri ve kerahat vakitleri tek çemberde.",
      "Today's prayer and makruh times in one circle.",
      "مواقيت اليوم وأوقات الكراهة في دائرة واحدة.",
    ],
    "ring.forbidden": ["Kerahat", "Makruh", "كراهة", "Makruh", "Makruh", "Makruh", "مکروہ", "Mekruh", "Макрух"],
  ]
}
