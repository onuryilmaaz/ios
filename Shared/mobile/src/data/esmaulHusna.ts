import esmaEn from '@/data/i18n/esmaulHusna.en.json';

export type EsmaName = {
  id: number;
  name: string; // Latin
  arabic: string; // Arapça
  meaning: string; // Kısa anlam
};

export const ESMAUL_HUSNA: EsmaName[] = [
  {
    id: 1,
    name: 'Er-Rahmân',
    arabic: 'الرَّحْمَٰنُ',
    meaning: 'Dünyada bütün canlılara merhamet eden.',
  },
  {
    id: 2,
    name: 'Er-Rahîm',
    arabic: 'الرَّحِيمُ',
    meaning: 'Ahirette yalnız müminlere merhamet eden.',
  },
  {
    id: 3,
    name: 'El-Melik',
    arabic: 'الْمَلِكُ',
    meaning: 'Bütün kâinatın gerçek sahibi ve hükümdarı.',
  },
  {
    id: 4,
    name: 'El-Kuddûs',
    arabic: 'الْقُدُّوسُ',
    meaning: 'Her türlü eksiklikten münezzeh olan.',
  },
  {
    id: 5,
    name: 'Es-Selâm',
    arabic: 'السَّلَامُ',
    meaning: 'Her türlü tehlikeden selamette olan.',
  },
  {
    id: 6,
    name: "El-Mü'min",
    arabic: 'الْمُؤْمِنُ',
    meaning: 'Güven veren, kullarını emin kılan.',
  },
  { id: 7, name: 'El-Müheymin', arabic: 'الْمُهَيْمِنُ', meaning: 'Her şeyi gözeten, koruyan.' },
  {
    id: 8,
    name: 'El-Azîz',
    arabic: 'الْعَزِيزُ',
    meaning: 'Mağlup edilmesi mümkün olmayan, izzet sahibi.',
  },
  {
    id: 9,
    name: 'El-Cebbâr',
    arabic: 'الْجَبَّارُ',
    meaning: 'Dilediğini zorla yaptırmaya kadir olan.',
  },
  { id: 10, name: 'El-Mütekebbir', arabic: 'الْمُتَكَبِّرُ', meaning: 'Büyüklükte tek olan.' },
  { id: 11, name: 'El-Hâlık', arabic: 'الْخَالِقُ', meaning: 'Her şeyi yoktan var eden.' },
  {
    id: 12,
    name: "El-Bâri'",
    arabic: 'الْبَارِئُ',
    meaning: 'Yarattıklarını mükemmel şekilde uyumlu yapan.',
  },
  {
    id: 13,
    name: 'El-Musavvir',
    arabic: 'الْمُصَوِّرُ',
    meaning: 'Her varlığa şekil ve suret veren.',
  },
  {
    id: 14,
    name: 'El-Gaffâr',
    arabic: 'الْغَفَّارُ',
    meaning: 'Kullarının günahlarını çokça bağışlayan.',
  },
  { id: 15, name: 'El-Kahhâr', arabic: 'الْقَهَّارُ', meaning: 'Her şeye galip gelen.' },
  { id: 16, name: 'El-Vehhâb', arabic: 'الْوَهَّابُ', meaning: 'Karşılıksız ve bolca veren.' },
  { id: 17, name: 'Er-Rezzâk', arabic: 'الرَّزَّاقُ', meaning: 'Her canlının rızkını veren.' },
  {
    id: 18,
    name: 'El-Fettâh',
    arabic: 'الْفَتَّاحُ',
    meaning: 'Her türlü güçlüğü açan, hayır kapılarını açan.',
  },
  { id: 19, name: 'El-Alîm', arabic: 'الْعَلِيمُ', meaning: 'Her şeyi en iyi bilen.' },
  {
    id: 20,
    name: 'El-Kâbız',
    arabic: 'الْقَابِضُ',
    meaning: 'Dilediği şeyi tutan, sıkan, daraltan.',
  },
  { id: 21, name: 'El-Bâsıt', arabic: 'الْبَاسِطُ', meaning: 'Dilediğine bolluk veren.' },
  { id: 22, name: 'El-Hâfid', arabic: 'الْخَافِضُ', meaning: 'Kâfirleri alçaltan, indiren.' },
  { id: 23, name: "Er-Râfi'", arabic: 'الرَّافِعُ', meaning: 'Şereflendirip yükselten.' },
  { id: 24, name: 'El-Muizz', arabic: 'الْمُعِزُّ', meaning: 'Dilediğine izzet, üstünlük veren.' },
  { id: 25, name: 'El-Müzill', arabic: 'الْمُذِلُّ', meaning: 'Dilediğini zelil, hor kılan.' },
  { id: 26, name: "Es-Semî'", arabic: 'السَّمِيعُ', meaning: 'Her şeyi işiten.' },
  { id: 27, name: 'El-Basîr', arabic: 'الْبَصِيرُ', meaning: 'Her şeyi gören.' },
  { id: 28, name: 'El-Hakem', arabic: 'الْحَكَمُ', meaning: 'Hükmedici, hakkı yerine getiren.' },
  { id: 29, name: 'El-Adl', arabic: 'الْعَدْلُ', meaning: 'Mutlak adaletli olan.' },
  {
    id: 30,
    name: 'El-Latîf',
    arabic: 'اللَّطِيفُ',
    meaning: 'Lütuf ve ihsan sahibi, ince işleri bilen.',
  },
  { id: 31, name: 'El-Habîr', arabic: 'الْخَبِيرُ', meaning: 'Her şeyden haberdar olan.' },
  { id: 32, name: 'El-Halîm', arabic: 'الْحَلِيمُ', meaning: 'Yumuşak davranan, hilim sahibi.' },
  { id: 33, name: 'El-Azîm', arabic: 'الْعَظِيمُ', meaning: 'Pek büyük, azamet sahibi.' },
  { id: 34, name: 'El-Gafûr', arabic: 'الْغَفُورُ', meaning: 'Çok bağışlayan, mağfiret eden.' },
  { id: 35, name: 'Eş-Şekûr', arabic: 'الشَّكُورُ', meaning: 'Az amele çok mükâfat veren.' },
  { id: 36, name: 'El-Aliyy', arabic: 'الْعَلِيُّ', meaning: 'Yüce, üstün olan.' },
  { id: 37, name: 'El-Kebîr', arabic: 'الْكَبِيرُ', meaning: 'Pek büyük olan.' },
  { id: 38, name: 'El-Hafîz', arabic: 'الْحَفِيظُ', meaning: 'Her şeyi koruyan, muhafaza eden.' },
  {
    id: 39,
    name: 'El-Mukît',
    arabic: 'الْمُقِيتُ',
    meaning: 'Bedenlerin ve ruhların gıdasını veren.',
  },
  { id: 40, name: 'El-Hasîb', arabic: 'الْحَسِيبُ', meaning: 'Kullarına yeten, hesaba çeken.' },
  { id: 41, name: 'El-Celîl', arabic: 'الْجَلِيلُ', meaning: 'Celal sahibi, ululuk sahibi.' },
  { id: 42, name: 'El-Kerîm', arabic: 'الْكَرِيمُ', meaning: 'Pek cömert, ikram sahibi.' },
  { id: 43, name: 'Er-Rakîb', arabic: 'الرَّقِيبُ', meaning: 'Her şeyi gözetleyen, kontrol eden.' },
  { id: 44, name: 'El-Mucîb', arabic: 'الْمُجِيبُ', meaning: 'Dualara icabet eden.' },
  { id: 45, name: "El-Vâsi'", arabic: 'الْوَاسِعُ', meaning: 'Lütfü, ilmi ve rahmeti geniş olan.' },
  { id: 46, name: 'El-Hakîm', arabic: 'الْحَكِيمُ', meaning: 'Hüküm ve hikmet sahibi.' },
  { id: 47, name: 'El-Vedûd', arabic: 'الْوَدُودُ', meaning: 'Kullarını seven, sevilen.' },
  { id: 48, name: 'El-Mecîd', arabic: 'الْمَجِيدُ', meaning: 'Şanı yüce, şeref sahibi.' },
  { id: 49, name: "El-Bâ'is", arabic: 'الْبَاعِثُ', meaning: 'Öldükten sonra dirilten.' },
  { id: 50, name: 'Eş-Şehîd', arabic: 'الشَّهِيدُ', meaning: 'Her şeye şahit olan.' },
  { id: 51, name: 'El-Hakk', arabic: 'الْحَقُّ', meaning: 'Varlığı değişmez, mutlak doğru olan.' },
  { id: 52, name: 'El-Vekîl', arabic: 'الْوَكِيلُ', meaning: 'Tevekkül edenlerin işlerini gören.' },
  { id: 53, name: 'El-Kaviyy', arabic: 'الْقَوِيُّ', meaning: 'Pek kuvvetli, güçlü olan.' },
  { id: 54, name: 'El-Metîn', arabic: 'الْمَتِينُ', meaning: 'Sağlam ve dayanıklı olan.' },
  { id: 55, name: 'El-Veliyy', arabic: 'الْوَلِيُّ', meaning: 'Müminlerin dostu ve yardımcısı.' },
  { id: 56, name: 'El-Hamîd', arabic: 'الْحَمِيدُ', meaning: 'Övgüye en layık olan.' },
  { id: 57, name: 'El-Muhsî', arabic: 'الْمُحْصِي', meaning: 'Her şeyi tek tek sayan, bilen.' },
  { id: 58, name: "El-Mübdi'", arabic: 'الْمُبْدِئُ', meaning: 'Mahlukatı örneksiz yaratan.' },
  {
    id: 59,
    name: 'El-Muîd',
    arabic: 'الْمُعِيدُ',
    meaning: 'Yarattıklarını öldürüp tekrar dirilten.',
  },
  { id: 60, name: 'El-Muhyî', arabic: 'الْمُحْيِي', meaning: 'Can veren, hayat bahşeden.' },
  { id: 61, name: 'El-Mümît', arabic: 'الْمُمِيتُ', meaning: 'Canı alan, öldüren.' },
  { id: 62, name: 'El-Hayy', arabic: 'الْحَيُّ', meaning: 'Ezelî ve ebedî diri olan.' },
  {
    id: 63,
    name: 'El-Kayyûm',
    arabic: 'الْقَيُّومُ',
    meaning: 'Kendi varlığı kendinden olan, her şeyi ayakta tutan.',
  },
  {
    id: 64,
    name: 'El-Vâcid',
    arabic: 'الْوَاجِدُ',
    meaning: 'İstediğini bulan, hiçbir şeye muhtaç olmayan.',
  },
  { id: 65, name: 'El-Mâcid', arabic: 'الْمَاجِدُ', meaning: 'Şanlı, şerefli, kerem sahibi.' },
  {
    id: 66,
    name: 'El-Vâhid',
    arabic: 'الْوَاحِدُ',
    meaning: 'Zatında, sıfatlarında bir olan, tek olan.',
  },
  { id: 67, name: 'El-Ehad', arabic: 'الْأَحَدُ', meaning: 'Tek, eşi ve benzeri olmayan.' },
  {
    id: 68,
    name: 'Es-Samed',
    arabic: 'الصَّمَدُ',
    meaning: 'Hiçbir şeye muhtaç olmayan, her şey ona muhtaç olan.',
  },
  { id: 69, name: 'El-Kâdir', arabic: 'الْقَادِرُ', meaning: 'Sonsuz kudret sahibi.' },
  {
    id: 70,
    name: 'El-Muktedir',
    arabic: 'الْمُقْتَدِرُ',
    meaning: 'Kudretini dilediği gibi kullanan.',
  },
  { id: 71, name: 'El-Mukaddim', arabic: 'الْمُقَدِّمُ', meaning: 'Dilediğini öne alan.' },
  { id: 72, name: "El-Mu'ahhir", arabic: 'الْمُؤَخِّرُ', meaning: 'Dilediğini geriye bırakan.' },
  { id: 73, name: 'El-Evvel', arabic: 'الْأَوَّلُ', meaning: 'Başlangıcı olmayan, ilk olan.' },
  { id: 74, name: 'El-Âhir', arabic: 'الْآخِرُ', meaning: 'Sonu olmayan, son olan.' },
  { id: 75, name: 'Ez-Zâhir', arabic: 'الظَّاهِرُ', meaning: 'Varlığı delillerle açıkça görünen.' },
  {
    id: 76,
    name: 'El-Bâtın',
    arabic: 'الْبَاطِنُ',
    meaning: 'Mahiyeti akıllarca idrak edilemeyen.',
  },
  { id: 77, name: 'El-Vâlî', arabic: 'الْوَالِي', meaning: 'Bütün kâinatı yöneten.' },
  {
    id: 78,
    name: 'El-Müteâlî',
    arabic: 'الْمُتَعَالِي',
    meaning: 'Yaratıkların sıfatlarından münezzeh olan.',
  },
  { id: 79, name: 'El-Berr', arabic: 'الْبَرُّ', meaning: 'İyilik ve ihsanı çok olan.' },
  { id: 80, name: 'Et-Tevvâb', arabic: 'التَّوَّابُ', meaning: 'Tevbeleri çokça kabul eden.' },
  {
    id: 81,
    name: 'El-Müntekım',
    arabic: 'الْمُنْتَقِمُ',
    meaning: 'Suçluları adaletiyle cezalandıran.',
  },
  { id: 82, name: 'El-Afüvv', arabic: 'الْعَفُوُّ', meaning: 'Affı çok olan, günahları silen.' },
  { id: 83, name: 'Er-Raûf', arabic: 'الرَّءُوفُ', meaning: 'Çok şefkatli, esirgeyen.' },
  { id: 84, name: "Mâlikü'l-Mülk", arabic: 'مَالِكُ الْمُلْكِ', meaning: 'Mülkün gerçek sahibi.' },
  {
    id: 85,
    name: "Zü'l-Celâli ve'l-İkrâm",
    arabic: 'ذُو الْجَلَالِ وَالْإِكْرَامِ',
    meaning: 'Celal ve ikram sahibi.',
  },
  { id: 86, name: 'El-Muksit', arabic: 'الْمُقْسِطُ', meaning: 'Adaletle hükmeden.' },
  { id: 87, name: "El-Câmi'", arabic: 'الْجَامِعُ', meaning: 'Mahşerde kullarını toplayan.' },
  {
    id: 88,
    name: 'El-Ganiyy',
    arabic: 'الْغَنِيُّ',
    meaning: 'Hiçbir şeye muhtaç olmayan, zengin olan.',
  },
  { id: 89, name: 'El-Muğnî', arabic: 'الْمُغْنِي', meaning: 'Dilediğini zengin yapan.' },
  {
    id: 90,
    name: "El-Mâni'",
    arabic: 'الْمَانِعُ',
    meaning: 'Dilediği şeyin meydana gelmesine engel olan.',
  },
  { id: 91, name: 'Ed-Dârr', arabic: 'الضَّارُّ', meaning: 'Hikmetiyle bazılarına zarar veren.' },
  { id: 92, name: "En-Nâfi'", arabic: 'النَّافِعُ', meaning: 'Hayır ve fayda veren.' },
  { id: 93, name: 'En-Nûr', arabic: 'النُّورُ', meaning: 'Âlemleri nurlandıran, ışık olan.' },
  { id: 94, name: 'El-Hâdî', arabic: 'الْهَادِي', meaning: 'Hidayet veren, doğru yola eriştiren.' },
  {
    id: 95,
    name: "El-Bedî'",
    arabic: 'الْبَدِيعُ',
    meaning: 'Eşi ve benzeri olmayan güzellikle yaratan.',
  },
  { id: 96, name: 'El-Bâkî', arabic: 'الْبَاقِي', meaning: 'Varlığı ebedî olan.' },
  { id: 97, name: 'El-Vâris', arabic: 'الْوَارِثُ', meaning: 'Bütün servetlerin gerçek sahibi.' },
  {
    id: 98,
    name: 'Er-Reşîd',
    arabic: 'الرَّشِيدُ',
    meaning: 'Bütün işleri sonsuz isabet ve hikmetle olan.',
  },
  {
    id: 99,
    name: 'Es-Sabûr',
    arabic: 'الصَّبُورُ',
    meaning: 'Çok sabırlı olan, acele cezalandırmayan.',
  },
];

/**
 * Seçili dildeki hâli. İngilizce: okunuş + anlam (`i18n/esmaulHusna.en.json`).
 * Arapça: isim zaten Arapça metindir; `name` Arapça olur, `meaning` boş kalır.
 */
export function localizeEsma(n: EsmaName, language: string): EsmaName {
  if (language === 'en') {
    const t = (esmaEn as Record<string, string[]>)[String(n.id)];
    return t ? { ...n, name: t[0] ?? n.name, meaning: t[1] ?? n.meaning } : n;
  }
  if (language === 'ar') return { ...n, name: n.arabic, meaning: '' };
  return n;
}
