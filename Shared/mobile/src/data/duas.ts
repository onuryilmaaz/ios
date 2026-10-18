export interface Dua {
  id: string;
  title: string;
  arabic: string;
  transliteration: string;
  turkish: string;
  source?: string;
}

export interface DuaCategory {
  id: string;
  title: string;
  icon: string;
  duas: Dua[];
}

export const DUA_CATEGORIES: DuaCategory[] = [
  {
    id: 'sabah',
    title: 'Sabah Duaları',
    icon: 'sunny-outline',
    duas: [
      {
        id: 'sabah-1',
        title: 'Sabah Uyanış Duası',
        arabic: 'اَلْحَمْدُ لِلّٰهِ الَّذِى أَحْيَانَا بَعْدَ مَآ أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
        transliteration: "Elhamdülillâhillezî ahyânâ ba'de mâ emâtenâ ve ileyhin-nüşûr.",
        turkish: "Bizi öldürdükten sonra dirilten Allah'a hamd olsun. Dönüş O'nadır.",
        source: 'Buhârî, Müslim',
      },
      {
        id: 'sabah-2',
        title: 'Sabah Zikri',
        arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلّٰهِ وَالْحَمْدُ لِلّٰهِ',
        transliteration: 'Esbahnâ ve esbahal-mülkü lillâh, vel-hamdü lillâh.',
        turkish: "Sabahladık, mülk de Allah'a aittir. Hamd Allah'a mahsustur.",
        source: 'Müslim',
      },
      {
        id: 'sabah-3',
        title: 'Sabah Selameti Duası',
        arabic:
          'اَللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
        transliteration:
          'Allâhümme bike asbahnâ ve bike emseynâ ve bike nahyâ ve bike nemûtü ve ileyken-nüşûr.',
        turkish:
          "Allah'ım! Senin adınla sabahladık, senin adınla akşamladık, seninle yaşar seninle ölürüz. Dönüş sanadır.",
        source: 'Tirmizî',
      },
    ],
  },
  {
    id: 'aksam',
    title: 'Akşam Duaları',
    icon: 'moon-outline',
    duas: [
      {
        id: 'aksam-1',
        title: 'Akşam Zikri',
        arabic: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلّٰهِ وَالْحَمْدُ لِلّٰهِ',
        transliteration: 'Emseynâ ve emsel-mülkü lillâh, vel-hamdü lillâh.',
        turkish: "Akşamladık. Mülk de Allah'a aittir. Hamd Allah'a mahsustur.",
        source: 'Müslim',
      },
      {
        id: 'aksam-2',
        title: 'Akşam Korunma Duası',
        arabic:
          'اَللَّهُمَّ إِنِّى أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ أَنَّكَ أَنْتَ اللّٰهُ لَا إِلٰهَ إِلَّا أَنْتَ',
        transliteration:
          'Allâhümme innî emseytü üşhidüke ve üşhidü hamele arşike ve melâiketek ve cemîa halkıke enneke entallâhü lâ ilâhe illâ ent.',
        turkish:
          "Allah'ım! Akşamladım; seni, arşını taşıyanları, meleklerini ve tüm yaratıklarını tanık tutuyorum ki; sen Allah'sın, senden başka ilah yoktur.",
        source: 'Ebû Dâvûd',
      },
    ],
  },
  {
    id: 'yemek',
    title: 'Yemek Duaları',
    icon: 'restaurant-outline',
    duas: [
      {
        id: 'yemek-1',
        title: 'Yemek Öncesi',
        arabic: 'بِسْمِ اللّٰهِ وَعَلَى بَرَكَةِ اللّٰهِ',
        transliteration: 'Bismillâhi ve alâ beraketillâh.',
        turkish: "Allah'ın adıyla ve Allah'ın bereketi ile (yiyorum).",
        source: 'Ebû Dâvûd',
      },
      {
        id: 'yemek-2',
        title: 'Yemek Sonrası',
        arabic: 'اَلْحَمْدُ لِلّٰهِ الَّذِى أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ',
        transliteration: "Elhamdülillâhillezî et'amenâ ve sekânâ ve ce'alenâ müslimîn.",
        turkish: "Bizi doyuran, içiren ve Müslüman kılan Allah'a hamd olsun.",
        source: 'Tirmizî',
      },
      {
        id: 'yemek-3',
        title: 'Yemeği Unutunca',
        arabic: 'بِسْمِ اللّٰهِ أَوَّلَهُ وَآخِرَهُ',
        transliteration: 'Bismillâhi evvelehû ve âhirehû.',
        turkish: "Allah'ın adıyla, başında da sonunda da.",
        source: 'Ebû Dâvûd, Tirmizî',
      },
    ],
  },
  {
    id: 'uyku',
    title: 'Uyku Duaları',
    icon: 'bed-outline',
    duas: [
      {
        id: 'uyku-1',
        title: 'Uyumadan Önce',
        arabic: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
        transliteration: 'Bismikallâhümme emûtü ve ahyâ.',
        turkish: "Allah'ım! Senin adınla ölür (uyur) ve dirilir (uyanırım).",
        source: 'Buhârî',
      },
      {
        id: 'uyku-2',
        title: 'Yatağa Girerken',
        arabic: 'اَللَّهُمَّ قِنِى عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
        transliteration: "Allâhümme kınî azâbeke yevme teb'asü ibâdek.",
        turkish: "Allah'ım! Kullarını yeniden dirilttiğin gün beni azabından koru.",
        source: 'Ebû Dâvûd, Tirmizî',
      },
      {
        id: 'uyku-3',
        title: 'Kabus Görünce',
        arabic:
          'أَعُوذُ بِكَلِمَاتِ اللّٰهِ التَّامَّةِ مِنْ غَضَبِهِ وَعِقَابِهِ وَشَرِّ عِبَادِهِ وَمِنْ هَمَزَاتِ الشَّيَاطِينِ',
        transliteration:
          "E'ûzü bikelimâtillâhit-tâmmeti min gadabihî ve ikâbihî ve şerri ibâdihî ve min hemezâtiş-şeyâtîn.",
        turkish:
          "Allah'ın tam sözleri ile O'nun gazabından, azabından, kullarının şerrinden ve şeytanların vesveselerinden Allah'a sığınırım.",
        source: 'Tirmizî',
      },
    ],
  },
  {
    id: 'yolculuk',
    title: 'Yolculuk Duaları',
    icon: 'car-outline',
    duas: [
      {
        id: 'yolculuk-1',
        title: 'Taşıta Binerken',
        arabic:
          'بِسْمِ اللّٰهِ وَالْحَمْدُ لِلّٰهِ سُبْحَانَ الَّذِى سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
        transliteration:
          'Bismillâhi vel-hamdü lillâh. Sübhânellezî sehhara lenâ hâzâ ve mâ künnâ lehü mukrinîn, ve innâ ilâ rabbinâ lemünkalibûn.',
        turkish:
          "Allah'ın adıyla. Hamd Allah'a. Bunu bize boyun eğdiren yücedir, yoksa biz buna güç yetiremezdik. Şüphesiz biz Rabbimize döneceğiz.",
        source: 'Tirmizî',
      },
      {
        id: 'yolculuk-2',
        title: 'Sefer Duası',
        arabic: 'اَللَّهُمَّ إِنَّا نَسْأَلُكَ فِى سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى',
        transliteration: "Allâhümme innâ nes'elüke fî seferinâ hâzel-birra vet-takvâ.",
        turkish: "Allah'ım! Seferimizde senden iyilik ve takva istiyoruz.",
        source: 'Müslim',
      },
    ],
  },
  {
    id: 'namaz-sonrasi',
    title: 'Namaz Sonrası',
    icon: 'hand-left-outline',
    duas: [
      {
        id: 'ns-1',
        title: 'Namaz Sonrası Dua',
        arabic: 'اَللَّهُمَّ أَعِنِّى عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
        transliteration: "Allâhümme a'innî alâ zikrike ve şükrike ve hüsni ibâdetik.",
        turkish:
          "Allah'ım! Seni zikretmek, sana şükretmek ve güzel ibadet etmek için bana yardım et.",
        source: 'Ebû Dâvûd',
      },
      {
        id: 'ns-2',
        title: 'Seyyidül İstiğfar',
        arabic:
          'اَللَّهُمَّ أَنْتَ رَبِّى لَا إِلٰهَ إِلَّا أَنْتَ خَلَقْتَنِى وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ',
        transliteration:
          "Allâhümme ente rabbî lâ ilâhe illâ ent. Halaktenî ve ene abdük, ve ene alâ ahdike ve va'dike mesteta't. E'ûzü bike min şerri mâ sana't.",
        turkish:
          "Allah'ım, sen benim Rabbimsin. Senden başka ilah yoktur. Beni sen yarattın, ben senin kulunum ve gücüm yettiğince ahdinde ve vaadinde duruyorum. Yaptıklarımın şerrinden sana sığınıyorum.",
        source: 'Buhârî',
      },
      {
        id: 'ns-3',
        title: 'Kul Hüvellah',
        arabic: 'قُلْ هُوَ اللّٰهُ أَحَدٌ',
        transliteration: 'Kul huvallâhu ehad.',
        turkish: "De ki: O Allah'tır, bir tektir.",
        source: "Kur'an, İhlas Suresi",
      },
    ],
  },
  {
    id: 'genel',
    title: 'Genel Dualar',
    icon: 'heart-outline',
    duas: [
      {
        id: 'genel-1',
        title: 'Rabbena Duası',
        arabic:
          'رَبَّنَا آتِنَا فِى الدُّنْيَا حَسَنَةً وَفِى الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
        transliteration:
          'Rabbenâ âtinâ fid-dünyâ haseneten ve fil-âhirati haseneten ve kınâ azâben-nâr.',
        turkish:
          'Rabbimiz! Bize dünyada iyilik, ahirette de iyilik ver ve bizi ateş azabından koru.',
        source: "Kur'an, Bakara 201",
      },
      {
        id: 'genel-2',
        title: 'Kalp Salimliği',
        arabic: 'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِى عَلَى دِينِكَ',
        transliteration: 'Yâ mukallibel-kulûbi sebbit kalbî alâ dînik.',
        turkish: 'Ey kalpleri halden hale çeviren! Kalbimi dininde sabit kıl.',
        source: 'Tirmizî',
      },
      {
        id: 'genel-3',
        title: 'Sıkıntı Duası',
        arabic: 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّى كُنْتُ مِنَ الظَّالِمِينَ',
        transliteration: 'Lâ ilâhe illâ ente sübhâneke innî küntü minez-zâlimîn.',
        turkish: 'Senden başka ilah yoktur. Seni tenzih ederim. Gerçekten ben zalimlerden oldum.',
        source: "Kur'an, Enbiya 87",
      },
    ],
  },
];

/** Düz dua listesi ve id→dua haritası (öneri/eşleme için). */
export const ALL_DUAS: Dua[] = DUA_CATEGORIES.flatMap((c) => c.duas);
const DUA_BY_ID: Record<string, Dua> = Object.fromEntries(ALL_DUAS.map((d) => [d.id, d]));
function getDuaById(id: string): Dua | undefined {
  return DUA_BY_ID[id];
}
export function getDuasByIds(ids: string[]): Dua[] {
  return ids.map(getDuaById).filter((d): d is Dua => Boolean(d));
}

/** "Duruma göre" hızlı ruh hâli / durum eşlemeleri (anında, çevrimdışı). */
export interface DuaSituation {
  key: string;
  label: string;
  icon: string;
  duaIds: string[];
  keywords: string[]; // AI kapalıyken serbest metni eşlemek için
}

export const DUA_SITUATIONS: DuaSituation[] = [
  {
    key: 'kaygi',
    label: 'Kaygı / Stres',
    icon: 'rainy-outline',
    duaIds: ['genel-3', 'genel-2', 'aksam-2'],
    keywords: ['kaygı', 'stres', 'endişe', 'sıkıntı', 'üzgün', 'bunalım', 'huzursuz', 'panik'],
  },
  {
    key: 'sukur',
    label: 'Şükür',
    icon: 'heart-outline',
    duaIds: ['yemek-2', 'ns-1', 'sabah-1'],
    keywords: ['şükür', 'minnet', 'mutlu', 'sevinç', 'nimet', 'teşekkür'],
  },
  {
    key: 'yolculuk',
    label: 'Yolculuk',
    icon: 'airplane-outline',
    duaIds: ['yolculuk-1', 'yolculuk-2'],
    keywords: ['yolculuk', 'sefer', 'seyahat', 'yola', 'gidiyorum', 'uçak', 'araba'],
  },
  {
    key: 'korunma',
    label: 'Korku / Korunma',
    icon: 'shield-outline',
    duaIds: ['aksam-2', 'uyku-3', 'genel-3'],
    keywords: ['korku', 'korkuyorum', 'korunma', 'nazar', 'kötülük', 'şer', 'kabus'],
  },
  {
    key: 'uyku',
    label: 'Uyku',
    icon: 'moon-outline',
    duaIds: ['uyku-1', 'uyku-2', 'uyku-3'],
    keywords: ['uyku', 'uyuyacağım', 'gece', 'yatağa', 'uykusuz'],
  },
  {
    key: 'tovbe',
    label: 'Tövbe / İstiğfar',
    icon: 'refresh-outline',
    duaIds: ['ns-2', 'genel-3'],
    keywords: ['tövbe', 'istiğfar', 'günah', 'pişman', 'af', 'bağışla'],
  },
  {
    key: 'huzur',
    label: 'Huzur / Kalp',
    icon: 'leaf-outline',
    duaIds: ['genel-2', 'genel-1', 'ns-3'],
    keywords: ['huzur', 'kalp', 'sükunet', 'sakinlik', 'iç huzuru', 'rahat'],
  },
  {
    key: 'sabah',
    label: 'Güne Başlarken',
    icon: 'sunny-outline',
    duaIds: ['sabah-1', 'sabah-2', 'sabah-3'],
    keywords: ['sabah', 'güne', 'uyandım', 'başlangıç', 'yeni gün'],
  },
];
