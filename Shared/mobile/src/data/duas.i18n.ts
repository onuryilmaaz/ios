import i18n from '@/i18n';
import { DUA_CATEGORIES, DUA_SITUATIONS, type Dua, type DuaCategory } from '@/data/duas';

/**
 * Dua içeriklerinin İngilizce / Arapça karşılıkları. Türkçe asıl metin
 * `duas.ts`'te durur. Arapça arayüzde duanın Arapça metni zaten anlamın
 * kendisidir: okunuş ve meal gösterilmez, yalnız başlık ve kaynak çevrilir.
 *
 * İngilizce anlamlar yaygın İngilizce hadis/meal çevirilerinden uyarlanmıştır.
 */

type DuaText = { title: string; transliteration: string; meaning: string };

const SOURCES_AR: Record<string, string> = {
  'Buhârî, Müslim': 'البخاري ومسلم',
  Müslim: 'مسلم',
  Tirmizî: 'الترمذي',
  'Ebû Dâvûd': 'أبو داود',
  'Ebû Dâvûd, Tirmizî': 'أبو داود والترمذي',
  Buhârî: 'البخاري',
  "Kur'an, İhlas Suresi": 'القرآن، سورة الإخلاص',
  "Kur'an, Bakara 201": 'القرآن، البقرة 201',
  "Kur'an, Enbiya 87": 'القرآن، الأنبياء 87',
};

const SOURCES_EN: Record<string, string> = {
  'Buhârî, Müslim': 'Bukhari, Muslim',
  Müslim: 'Muslim',
  Tirmizî: 'Tirmidhi',
  'Ebû Dâvûd': 'Abu Dawud',
  'Ebû Dâvûd, Tirmizî': 'Abu Dawud, Tirmidhi',
  Buhârî: 'Bukhari',
  "Kur'an, İhlas Suresi": "Qur'an, Surah Al-Ikhlas",
  "Kur'an, Bakara 201": "Qur'an, Al-Baqarah 201",
  "Kur'an, Enbiya 87": "Qur'an, Al-Anbiya 87",
};

const CATEGORIES: Record<string, { en: string; ar: string }> = {
  sabah: { en: 'Morning Duas', ar: 'أذكار الصباح' },
  aksam: { en: 'Evening Duas', ar: 'أذكار المساء' },
  yemek: { en: 'Meal Duas', ar: 'أدعية الطعام' },
  uyku: { en: 'Sleep Duas', ar: 'أدعية النوم' },
  yolculuk: { en: 'Travel Duas', ar: 'أدعية السفر' },
  'namaz-sonrasi': { en: 'After Prayer', ar: 'بعد الصلاة' },
  genel: { en: 'General Duas', ar: 'أدعية عامة' },
};

const DUAS_EN: Record<string, DuaText> = {
  'sabah-1': {
    title: 'Upon Waking Up',
    transliteration: "Alhamdu lillahil-ladhi ahyana ba'da ma amatana wa ilayhin-nushur.",
    meaning:
      'All praise is for Allah, who gave us life after having taken it from us, and to Him is the return.',
  },
  'sabah-2': {
    title: 'Morning Remembrance',
    transliteration: 'Asbahna wa asbahal-mulku lillah, wal-hamdu lillah.',
    meaning:
      'We have entered the morning and the whole kingdom belongs to Allah. All praise is for Allah.',
  },
  'sabah-3': {
    title: 'Morning Protection',
    transliteration:
      'Allahumma bika asbahna wa bika amsayna wa bika nahya wa bika namutu wa ilaykan-nushur.',
    meaning:
      'O Allah, by You we enter the morning and by You we enter the evening, by You we live and by You we die, and to You is the resurrection.',
  },
  'aksam-1': {
    title: 'Evening Remembrance',
    transliteration: 'Amsayna wa amsal-mulku lillah, wal-hamdu lillah.',
    meaning:
      'We have entered the evening and the whole kingdom belongs to Allah. All praise is for Allah.',
  },
  'aksam-2': {
    title: 'Evening Protection',
    transliteration:
      "Allahumma inni amsaytu ush-hiduka wa ush-hidu hamalata 'arshika wa mala'ikataka wa jami'a khalqika annaka antallahu la ilaha illa ant.",
    meaning:
      'O Allah, I have entered the evening calling on You, the bearers of Your Throne, Your angels and all of Your creation to witness that You are Allah; there is no god but You.',
  },
  'yemek-1': {
    title: 'Before Eating',
    transliteration: "Bismillahi wa 'ala barakatillah.",
    meaning: 'In the name of Allah and with the blessings of Allah (I eat).',
  },
  'yemek-2': {
    title: 'After Eating',
    transliteration: "Alhamdu lillahil-ladhi at'amana wa saqana wa ja'alana muslimin.",
    meaning: 'All praise is for Allah who fed us, gave us drink and made us Muslims.',
  },
  'yemek-3': {
    title: 'If You Forget at the Start',
    transliteration: 'Bismillahi awwalahu wa akhirahu.',
    meaning: 'In the name of Allah, at its beginning and at its end.',
  },
  'uyku-1': {
    title: 'Before Sleeping',
    transliteration: 'Bismika Allahumma amutu wa ahya.',
    meaning: 'In Your name, O Allah, I die (sleep) and I live (wake).',
  },
  'uyku-2': {
    title: 'Getting Into Bed',
    transliteration: "Allahumma qini 'adhabaka yawma tab'athu 'ibadak.",
    meaning: 'O Allah, protect me from Your punishment on the Day You resurrect Your servants.',
  },
  'uyku-3': {
    title: 'After a Nightmare',
    transliteration:
      "A'udhu bikalimatillahit-tammati min ghadabihi wa 'iqabihi wa sharri 'ibadihi wa min hamazatish-shayatin.",
    meaning:
      'I seek refuge in the perfect words of Allah from His anger and His punishment, from the evil of His servants and from the whispers of the devils.',
  },
  'yolculuk-1': {
    title: 'Boarding a Vehicle',
    transliteration:
      'Bismillahi wal-hamdu lillah. Subhanal-ladhi sakhkhara lana hadha wa ma kunna lahu muqrinin, wa inna ila rabbina lamunqalibun.',
    meaning:
      'In the name of Allah, and all praise is for Allah. Glory be to Him who has subjected this to us, for we could never have done it by ourselves. And surely to our Lord we shall return.',
  },
  'yolculuk-2': {
    title: 'Travel Dua',
    transliteration: "Allahumma inna nas'aluka fi safarina hadhal-birra wat-taqwa.",
    meaning: 'O Allah, we ask You on this journey of ours for righteousness and piety.',
  },
  'ns-1': {
    title: 'After the Prayer',
    transliteration: "Allahumma a'inni 'ala dhikrika wa shukrika wa husni 'ibadatik.",
    meaning: 'O Allah, help me to remember You, to thank You and to worship You in the best way.',
  },
  'ns-2': {
    title: 'Sayyid al-Istighfar',
    transliteration:
      "Allahumma anta rabbi la ilaha illa ant. Khalaqtani wa ana 'abduk, wa ana 'ala 'ahdika wa wa'dika mastata't. A'udhu bika min sharri ma sana't.",
    meaning:
      'O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done.',
  },
  'ns-3': {
    title: 'Qul Huwallah',
    transliteration: 'Qul huwallahu ahad.',
    meaning: 'Say: He is Allah, the One.',
  },
  'genel-1': {
    title: 'Rabbana Dua',
    transliteration:
      "Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina 'adhaban-nar.",
    meaning:
      'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
  },
  'genel-2': {
    title: 'Steadfastness of the Heart',
    transliteration: "Ya muqallibal-qulubi thabbit qalbi 'ala dinik.",
    meaning: 'O Turner of hearts, keep my heart firm upon Your religion.',
  },
  'genel-3': {
    title: 'Dua in Distress',
    transliteration: 'La ilaha illa anta subhanaka inni kuntu minaz-zalimin.',
    meaning: 'There is no god but You. Glory be to You. Indeed, I have been among the wrongdoers.',
  },
};

const DUA_TITLES_AR: Record<string, string> = {
  'sabah-1': 'دعاء الاستيقاظ',
  'sabah-2': 'ذكر الصباح',
  'sabah-3': 'دعاء الصباح',
  'aksam-1': 'ذكر المساء',
  'aksam-2': 'دعاء الحفظ في المساء',
  'yemek-1': 'قبل الطعام',
  'yemek-2': 'بعد الطعام',
  'yemek-3': 'إذا نسي التسمية',
  'uyku-1': 'قبل النوم',
  'uyku-2': 'عند الاضطجاع',
  'uyku-3': 'عند الفزع في النوم',
  'yolculuk-1': 'دعاء الركوب',
  'yolculuk-2': 'دعاء السفر',
  'ns-1': 'دعاء دبر الصلاة',
  'ns-2': 'سيد الاستغفار',
  'ns-3': 'قل هو الله أحد',
  'genel-1': 'دعاء ربنا آتنا',
  'genel-2': 'دعاء الثبات',
  'genel-3': 'دعاء الكرب',
};

const SITUATIONS: Record<
  string,
  { en: string; ar: string; keywordsEn: string[]; keywordsAr: string[] }
> = {
  kaygi: {
    en: 'Anxiety / Stress',
    ar: 'القلق / التوتر',
    keywordsEn: ['anxious', 'anxiety', 'stress', 'worried', 'sad', 'upset', 'panic', 'restless'],
    keywordsAr: ['قلق', 'توتر', 'هم', 'حزن', 'ضيق', 'خوف'],
  },
  sukur: {
    en: 'Gratitude',
    ar: 'الشكر',
    keywordsEn: ['grateful', 'thankful', 'thanks', 'happy', 'joy', 'blessing'],
    keywordsAr: ['شكر', 'حمد', 'سعيد', 'فرح', 'نعمة'],
  },
  yolculuk: {
    en: 'Travel',
    ar: 'السفر',
    keywordsEn: ['travel', 'trip', 'journey', 'flight', 'driving', 'car', 'plane'],
    keywordsAr: ['سفر', 'رحلة', 'طائرة', 'سيارة'],
  },
  korunma: {
    en: 'Fear / Protection',
    ar: 'الخوف / الحفظ',
    keywordsEn: ['fear', 'afraid', 'scared', 'protection', 'evil eye', 'harm', 'nightmare'],
    keywordsAr: ['خوف', 'حفظ', 'حسد', 'عين', 'شر', 'كابوس'],
  },
  uyku: {
    en: 'Sleep',
    ar: 'النوم',
    keywordsEn: ['sleep', 'night', 'bed', 'insomnia', 'tired'],
    keywordsAr: ['نوم', 'ليل', 'أرق'],
  },
  tovbe: {
    en: 'Repentance',
    ar: 'التوبة / الاستغفار',
    keywordsEn: ['repent', 'repentance', 'forgive', 'forgiveness', 'sin', 'regret'],
    keywordsAr: ['توبة', 'استغفار', 'ذنب', 'مغفرة', 'ندم'],
  },
  huzur: {
    en: 'Peace / Heart',
    ar: 'الطمأنينة / القلب',
    keywordsEn: ['peace', 'heart', 'calm', 'serenity', 'tranquil'],
    keywordsAr: ['طمأنينة', 'قلب', 'سكينة', 'راحة', 'هدوء'],
  },
  sabah: {
    en: 'Starting the Day',
    ar: 'بداية اليوم',
    keywordsEn: ['morning', 'woke up', 'new day', 'start'],
    keywordsAr: ['صباح', 'استيقظت', 'يوم جديد'],
  },
};

const lang = () => i18n.language;

function duaCategoryTitle(id: string, fallback: string): string {
  const l = lang();
  if (l === 'en' || l === 'ar') return CATEGORIES[id]?.[l] ?? fallback;
  return fallback;
}

export function duaSituationLabel(key: string, fallback: string): string {
  const l = lang();
  if (l === 'en' || l === 'ar') return SITUATIONS[key]?.[l] ?? fallback;
  return fallback;
}

export function duaSituationKeywords(key: string, fallback: string[]): string[] {
  const l = lang();
  if (l === 'en') return SITUATIONS[key]?.keywordsEn ?? fallback;
  if (l === 'ar') return SITUATIONS[key]?.keywordsAr ?? fallback;
  return fallback;
}

/**
 * Duanın seçili dildeki hâli (aynı şekil; `turkish` alanı seçili dildeki
 * anlamı taşır). Arapça arayüzde `transliteration`/`turkish` boştur; ilgili
 * satırlar gizlenmelidir.
 */
export function localizeDua(dua: Dua): Dua {
  const l = lang();
  if (l === 'en') {
    const t = DUAS_EN[dua.id];
    return {
      ...dua,
      title: t?.title ?? dua.title,
      transliteration: t?.transliteration ?? dua.transliteration,
      turkish: t?.meaning ?? dua.turkish,
      source: dua.source ? (SOURCES_EN[dua.source] ?? dua.source) : undefined,
    };
  }
  if (l === 'ar') {
    return {
      ...dua,
      title: DUA_TITLES_AR[dua.id] ?? dua.title,
      transliteration: '',
      turkish: '',
      source: dua.source ? (SOURCES_AR[dua.source] ?? dua.source) : undefined,
    };
  }
  return dua;
}

/** Kategoriler ve duaları seçili dilde. */
export function localizedDuaCategories(): DuaCategory[] {
  return DUA_CATEGORIES.map((c) => ({
    ...c,
    title: duaCategoryTitle(c.id, c.title),
    duas: c.duas.map(localizeDua),
  }));
}

/** Serbest metni seçili dilin anahtar kelimeleriyle bir duruma eşler (AI kapalıyken). */
export function matchLocalizedSituation(text: string) {
  const t = text.toLocaleLowerCase(lang());
  let best: { sit: (typeof DUA_SITUATIONS)[number]; score: number } | null = null;
  for (const sit of DUA_SITUATIONS) {
    const keywords = duaSituationKeywords(sit.key, sit.keywords);
    const score = keywords.reduce((acc, kw) => (t.includes(kw) ? acc + 1 : acc), 0);
    if (score > 0 && (!best || score > best.score)) best = { sit, score };
  }
  return best?.sit ?? null;
}
