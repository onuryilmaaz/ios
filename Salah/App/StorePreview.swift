import Foundation

#if DEBUG
/// Mağaza görselleri için örnek oturum (`-SalahDebugSample YES`, izole): örnek kullanıcı, bugünkü namazlar,
/// seri, ibadet kayıtları, 12 aylık istatistik ve alarm ayarları. Yalnız bellekte; sunucuya ve sisteme
/// yazmaz. Android DebugLaunch `salah.debug.signedIn` + `tracker sample` + `alarms sample` karşılığı.
enum StorePreview {
  static func install() {
    // Kilit ekranı kartı ve widget'lar seçili dilde (normalde WidgetSync.activate yazar; izole modda çalışmaz).
    WidgetBridge.setLanguage(Localizer.shared.language.rawValue)
    AuthStore.shared.preview(AuthUser(id: "preview-user", email: "ornek@email.com", firstName: "Ayşe", lastName: "Yılmaz"))

    let cal = Calendar.current
    let today = Date()
    func day(_ offset: Int) -> String { localDateString(cal.date(byAdding: .day, value: offset, to: today) ?? today) }

    var stats = GamificationStore.Stats()
    stats.today_prayers = ["fajr", "dhuhr"]
    stats.kaza_prayers = ["fajr"]
    stats.current_streak = 12
    stats.highest_streak = 30
    let daily: [JSONValue] = (1...6).reversed().map { i in
      .object(["date": .string(day(-i)), "prayer_count": .number(Double([5, 5, 3, 5, 5, 0][6 - i]))])
    }
    GamificationStore.shared.preview(stats: stats, weekly: .object(["daily": .array(daily)]))

    let note: String
    switch Localizer.shared.language {
    case .en: note = "Al-Baqarah 15-18"
    case .ar: note = "البقرة ١٥-١٨"
    case .de, .fr: note = "Al-Baqara 15-18"
    case .id: note = "Al-Baqarah 15-18"
    case .ur: note = "البقرہ 15-18"
    case .ru: note = "аль-Бакара 15-18"
    case .es, .it, .ms: note = "Al-Baqarah 15-18"
    case .bn: note = "আল-বাকারা ১৫-১৮"
    case .hi: note = "अल-बक़रा 15-18"
    case .th: note = "อัล-บะเกาะเราะฮฺ 15-18"
    case .tr: note = "Bakara 15-18"
    }
    let journal: [AppLanguage: [(String, String)]] = [
      .tr: [("Annemin sağlığı için", "Allah'ım, anneme sağlık ve afiyet ver, ömrünü hayırla uzun eyle."), ("Sınavdan önce", "Allah'ım, işimi kolaylaştır, zorlaştırma. Gönlümü aç ve bana başarı nasip et."), ("Şükür", "Ailem, sağlığım ve sayamadığım her nimet için Elhamdülillah.")],
      .en: [("For my mother's health", "O Allah, grant my mother health and wellbeing, and give her a long life full of goodness."), ("Before exams", "O Allah, make it easy for me and do not make it hard. Open my heart and grant me success."), ("Gratitude", "Alhamdulillah for my family, my health and every blessing I cannot count.")],
      .ar: [("لصحة أمي", "اللهم ارزق أمي الصحة والعافية، وأطل عمرها في الخير."), ("قبل الامتحان", "اللهم يسّر ولا تعسّر، واشرح صدري، وارزقني التوفيق."), ("شكر", "الحمد لله على أسرتي وصحتي وكل نعمة لا أحصيها.")],
      .de: [("Für die Gesundheit meiner Mutter", "O Allah, schenke meiner Mutter Gesundheit und Wohlergehen und ein langes Leben voller Gutem."), ("Vor der Prüfung", "O Allah, mach es mir leicht und nicht schwer. Öffne mein Herz und schenke mir Erfolg."), ("Dankbarkeit", "Alhamdulillah für meine Familie, meine Gesundheit und jede Gabe, die ich nicht zählen kann.")],
      .fr: [("Pour la santé de ma mère", "Ô Allah, accorde à ma mère la santé et le bien-être, et une longue vie pleine de bien."), ("Avant l'examen", "Ô Allah, facilite-moi les choses et ne les rends pas difficiles. Ouvre mon cœur et accorde-moi la réussite."), ("Gratitude", "Alhamdulillah pour ma famille, ma santé et chaque bienfait que je ne peux compter.")],
      .id: [("Untuk kesehatan ibu", "Ya Allah, berilah ibuku kesehatan dan keselamatan, serta panjangkan umurnya dalam kebaikan."), ("Sebelum ujian", "Ya Allah, mudahkanlah dan jangan Engkau persulit. Lapangkan dadaku dan berilah aku keberhasilan."), ("Syukur", "Alhamdulillah atas keluargaku, kesehatanku, dan setiap nikmat yang tak terhitung.")],
      .ur: [("والدہ کی صحت کے لیے", "اے اللہ، میری والدہ کو صحت و عافیت عطا فرما اور ان کی عمر میں خیر کے ساتھ برکت دے۔"), ("امتحان سے پہلے", "اے اللہ، آسانی فرما اور مشکل نہ کر۔ میرا سینہ کھول دے اور مجھے کامیابی عطا فرما۔"), ("شکر", "اپنے گھر والوں، اپنی صحت اور ہر ان گنت نعمت پر الحمد للہ۔")],
      .ru: [("За здоровье мамы", "О Аллах, даруй моей маме здоровье и благополучие и продли её жизнь во благе."), ("Перед экзаменом", "О Аллах, облегчи и не усложняй. Раскрой мою грудь и даруй мне успех."), ("Благодарность", "Альхамдулиллях за мою семью, моё здоровье и каждую бесчисленную милость.")],
      .es: [("Por la salud de mi madre", "Oh Allah, concede a mi madre salud y bienestar, y dale una larga vida llena de bien."), ("Antes del examen", "Oh Allah, facilítamelo y no me lo pongas difícil. Abre mi corazón y concédeme el éxito."), ("Gratitud", "Alhamdulillah por mi familia, mi salud y cada bendición que no puedo contar.")],
      .it: [("Per la salute di mia madre", "O Allah, concedi a mia madre salute e benessere, e donale una lunga vita piena di bene."), ("Prima dell'esame", "O Allah, rendimi le cose facili e non difficili. Apri il mio cuore e concedimi il successo."), ("Gratitudine", "Alhamdulillah per la mia famiglia, la mia salute e ogni benedizione che non posso contare.")],
      .ms: [("Untuk kesihatan ibu", "Ya Allah, kurniakanlah ibuku kesihatan dan kesejahteraan, serta panjangkan umurnya dalam kebaikan."), ("Sebelum peperiksaan", "Ya Allah, permudahkanlah dan jangan Engkau persulitkan. Lapangkan dadaku dan kurniakanlah aku kejayaan."), ("Syukur", "Alhamdulillah atas keluargaku, kesihatanku dan setiap nikmat yang tidak terhitung.")],
      .bn: [("মায়ের সুস্থতার জন্য", "হে আল্লাহ, আমার মাকে সুস্থতা ও নিরাপত্তা দান করুন এবং কল্যাণের সাথে তাঁর হায়াত দীর্ঘ করুন।"), ("পরীক্ষার আগে", "হে আল্লাহ, সহজ করে দিন, কঠিন করবেন না। আমার অন্তর খুলে দিন এবং আমাকে সফলতা দান করুন।"), ("শুকরিয়া", "আমার পরিবার, আমার সুস্থতা এবং অগণিত প্রতিটি নিয়ামতের জন্য আলহামদুলিল্লাহ।")],
      .hi: [("अम्मी की सेहत के लिए", "ऐ अल्लाह, मेरी अम्मी को सेहत और आफ़ियत अता फ़रमा और भलाई के साथ उनकी उम्र लंबी कर।"), ("इम्तिहान से पहले", "ऐ अल्लाह, आसानी फ़रमा, मुश्किल न कर। मेरा सीना खोल दे और मुझे कामयाबी अता फ़रमा।"), ("शुक्र", "अपने घर वालों, अपनी सेहत और हर अनगिनत नेमत के लिए अल्हम्दुलिल्लाह।")],
      .th: [("เพื่อสุขภาพของแม่", "โอ้ อัลลอฮ์ โปรดประทานสุขภาพและความปลอดภัยแก่แม่ของฉัน และให้ท่านมีอายุยืนยาวในความดี"), ("ก่อนสอบ", "โอ้ อัลลอฮ์ โปรดทำให้ง่ายและอย่าทำให้ยาก โปรดเปิดหัวใจของฉันและประทานความสำเร็จแก่ฉัน"), ("ขอบคุณ", "อัลฮัมดุลิลลาฮ์ สำหรับครอบครัว สุขภาพ และทุกความโปรดปรานที่ฉันนับไม่ถ้วน")],
    ]
    let samples = journal[Localizer.shared.language] ?? journal[.en] ?? []
    DuaJournalStore.shared.preview(samples.enumerated().map { i, item in
      DuaJournalEntry(id: "j\(i)", title: item.0, text: item.1,
        reminder: i == 0 ? .init(hour: 21, minute: 0, days: [5]) : i == 1 ? .init(hour: 7, minute: 30, days: [1, 2, 3, 4, 5]) : nil)
    })
    #if PRAYER_LOCK
    PrayerLockStore.shared.preview()
    #endif

    let todayKey = day(0)
    TrackerStore.shared.preview([
      TrackerLog(id: "p1", date: todayKey, activity_type: "quran", value: .object(["pages": .number(4), "minutes": .number(20)]), notes: note, created_at: nil),
      TrackerLog(id: "p2", date: todayKey, activity_type: "nafile", value: .object(["type": .string("teheccud"), "rakaat": .number(2)]), notes: nil, created_at: nil),
      TrackerLog(id: "p3", date: todayKey, activity_type: "sadaka", value: .object(["amount": .number(100)]), notes: nil, created_at: nil),
    ])

    let pattern = [5, 5, 3, 5, 0, 4, 5, 2, 5, 5, 1]
    let ozel = Set((40..<46).map { day(-$0) })
    let days: [InsightsStore.HistoryDay] = (0..<371).reversed().map { i in
      let d = cal.date(byAdding: .day, value: -i, to: today) ?? today
      let key = localDateString(d)
      let count = ozel.contains(key) ? 0 : pattern[(i * 7 + cal.component(.day, from: d)) % pattern.count]
      return InsightsStore.HistoryDay(date: key, count: count, kaza: nil)
    }
    let weekday = (cal.component(.weekday, from: today) + 5) % 7 + 1  // Pazartesi = 1
    let weekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
    let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    func recap(_ period: String, _ from: Date, _ n: Int) -> InsightsStore.Recap {
      InsightsStore.Recap(
        period: period, from: localDateString(from), to: todayKey, days: n, prayers: n * 4, possiblePrayers: n * 5,
        kaza: 2, perfectDays: n / 2,
        byPrayerTime: ["fajr": n - 2, "dhuhr": n, "asr": n - 1, "maghrib": n, "isha": n - 1],
        quranPages: n * 3, activities: ["quran": n, "nafile": 3, "sadaka": 1], currentStreak: 12, highestStreak: 30)
    }
    InsightsStore.shared.preview(
      history: .init(
        from: days.first?.date ?? todayKey, to: todayKey, days: days, ozelGun: Array(ozel),
        nafile: days.enumerated().filter { $0.offset % 4 == 1 && $0.element.count > 0 }.map { .init(date: $0.element.date, count: 1, rakaat: 2) }),
      recaps: [
        "week": recap("week", weekStart, max(3, weekday)),
        "month": recap("month", monthStart, max(5, cal.component(.day, from: today))),
      ],
      quran: .init(totalPages: 1210, completedHatims: 1, currentPages: 206, pagesPerHatim: 604))

    var alarms = AlarmSettings.defaults
    alarms.prayers["imsak"] = .init(enabled: true, offset: 15)
    alarms.prayers["ogle"] = .init(enabled: true, offset: 0)
    alarms.tahajjud.enabled = true
    alarms.custom = [
      .init(id: "preview", hour: 9, minute: 30, days: [1, 2, 3, 4, 5], onceAt: nil, label: t("alarm.custom.labelPlaceholder"), enabled: true),
      .init(id: "preview2", hour: 22, minute: 0, days: [], onceAt: nil, label: "", enabled: true),
    ]
    var next = cal.date(byAdding: .day, value: 1, to: today) ?? today
    next = cal.date(bySettingHour: 5, minute: 56, second: 0, of: next) ?? next
    AlarmStore.shared.preview(alarms, next: (next, t("alarm.title.after", ["prayer": prayerLabel("imsak"), "min": 15])))
  }
}
#endif
