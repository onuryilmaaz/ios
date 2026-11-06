import Foundation

/// Ülke/il/ilçe verisi. Türkiye: RN ile ortak dosyalar (mobile/src/constants/states.json,
/// all-districts.json). Yurtdışı: Diyanet'in ülke/eyalet/şehir listesi (world-locations.json,
/// ezanvakti.imsakiyem.com'dan üretilir; aynı ilçe kimlikleriyle aynı vakit ucu kullanılır).
/// Seçim RN ile aynı anahtarlarda tutulur; ülke seçili ilin ülkesinden çıkar.
enum Locations {
  struct State: Decodable, Sendable {
    let _id: String
    let name: String
    let name_en: String
    /// Türkiye dosyasında "2"; yurtdışında ülkenin Diyanet kimliği.
    let country_id: String?

    var countryId: String { country_id ?? turkeyId }
  }

  struct District: Decodable, Sendable {
    let _id: String
    let name: String
    let name_en: String
    let state_id: String
  }

  struct Country: Decodable, Sendable {
    let id: String
    /// Diyanet'teki (Türkçe) ad; ISO kodu yoksa ya da çevirisi bulunamazsa gösterilir.
    let name: String
    let iso: String?
    /// Konumdan tespitte kullanılan ISO kodu (ör. Kuzey Kıbrıs: CY); yoksa `iso`.
    let geo: String?

    /// Uygulama dilinde ülke adı.
    var displayName: String {
      iso.flatMap { Localizer.shared.locale.localizedString(forRegionCode: $0) } ?? name
    }
  }

  static let turkeyId = "2"

  static let districtIdKey = "SELECTED_DISTRICT_ID"
  static let stateIdKey = "SELECTED_STATE_ID"
  static let sourceKey = "SELECTED_DISTRICT_SOURCE"

  static var selectedDistrictId: String {
    LocalStore.string(districtIdKey) ?? PrayerTimesService.defaultDistrictId
  }

  static var selectedStateId: String? { LocalStore.string(stateIdKey) }

  /// Seçili ilin ülkesi (seçim yoksa Türkiye).
  static var selectedCountryId: String {
    selectedStateId.flatMap { state($0) }?.countryId ?? turkeyId
  }

  static func state(_ id: String) -> State? {
    states.first { $0._id == id } ?? world.statesById[id]
  }

  static func districts(ofState id: String) -> [District] {
    let tr = districts.filter { $0.state_id == id }
    return tr.isEmpty ? world.districtsByState[id] ?? [] : tr
  }

  static func district(_ id: String) -> District? {
    districts.first { $0._id == id } ?? world.districtsById[id]
  }

  /// Seçim listesi: Türkiye başta, diğerleri uygulama dilinde alfabetik.
  static var countries: [Country] {
    let locale = Localizer.shared.locale
    let turkey = Country(id: turkeyId, name: "Türkiye", iso: "TR", geo: nil)
    let others = world.countries.sorted {
      $0.displayName.compare($1.displayName, locale: locale) == .orderedAscending
    }
    return [turkey] + others
  }

  static func country(_ id: String) -> Country? { countries.first { $0.id == id } }

  static func states(ofCountry id: String) -> [State] {
    id == turkeyId ? states : world.states.filter { $0.country_id == id }
  }

  /// İlin varsayılan ilçesi: il adıyla aynı olan ilçe (merkez), yoksa ilk ilçe.
  static func defaultDistrict(ofState id: String) -> District? {
    let list = districts(ofState: id)
    if let s = state(id),
      let center = list.first(where: { $0.name.uppercased() == s.name.uppercased() || $0.name_en.uppercased() == s.name_en.uppercased() })
    {
      return center
    }
    return list.first
  }

  /// Ters coğrafi kodlamadan gelen bölge adıyla il eşlemesi (Türkçe karakterler sadeleştirilir).
  static func state(matching region: String) -> State? {
    func normalize(_ s: String) -> String {
      s.uppercased(with: Locale(identifier: "tr_TR"))
        .replacingOccurrences(of: "İ", with: "I").replacingOccurrences(of: "Ğ", with: "G")
        .replacingOccurrences(of: "Ş", with: "S").replacingOccurrences(of: "Ç", with: "C")
        .replacingOccurrences(of: "Ö", with: "O").replacingOccurrences(of: "Ü", with: "U")
        .trimmingCharacters(in: .whitespaces)
    }
    let target = normalize(region)
    return states.first { normalize($0.name) == target || normalize($0.name_en) == target }
  }

  /// Yurtdışı konum eşlemesi. `names`: ters coğrafi kodlamadan şehir, alt bölge, bölge (Türkçe yerel
  /// ayarla; Diyanet adları da Türkçe). Önce şehir adı, sonra eyalet adı (merkez şehri), ülkede tek
  /// şehir varsa o.
  static func foreignMatch(iso: String, names: [String]) -> (state: State, district: District)? {
    guard let country = world.countries.first(where: { ($0.geo ?? $0.iso) == iso }) else { return nil }
    let sts = states(ofCountry: country.id)
    let all = sts.flatMap { districts(ofState: $0._id) }
    let keys = names.map(foldKey).filter { !$0.isEmpty }
    for k in keys {
      if let d = all.first(where: { foldKey($0.name) == k }), let s = state(d.state_id) { return (s, d) }
    }
    for k in keys {
      if let s = sts.first(where: { foldKey($0.name) == k }), let d = defaultDistrict(ofState: s._id) { return (s, d) }
    }
    if all.count == 1, let d = all.first, let s = state(d.state_id) { return (s, d) }
    return nil
  }

  /// Büyük harf, aksansız, yalnız harf/rakam: "Münih" / "MUNIH" → "MUNIH".
  static func foldKey(_ s: String) -> String {
    s.replacingOccurrences(of: "İ", with: "I").replacingOccurrences(of: "ı", with: "i")
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      .uppercased()
      .filter { $0.isLetter || $0.isNumber }
  }

  /// Seçimi kaydeder (RN ile aynı anahtarlar) ve ekranlara yeniden okuma sinyali verir.
  /// - Parameter source: "manual" (kullanıcı seçti) ya da "auto" (konumdan bulundu).
  static func select(stateId: String, districtId: String, source: String) {
    if LocationWatch.isManualChange(previousDistrictId: LocalStore.string(districtIdKey), districtId: districtId, source: source) {
      LocationWatch.resetAfterManualChange()
    }
    LocalStore.set(stateId, for: stateIdKey)
    LocalStore.set(districtId, for: districtIdKey)
    LocalStore.set(source, for: sourceKey)
    LocationChanges.shared.nonce += 1
  }

  /// Türkiye verisi büyük harfle gelir ("KOCAELİ"); Türkçe kurallarına göre "Kocaeli" yapar.
  /// Yurtdışı adları dosyada zaten düzgün yazılı ("Berlin"); onlara dokunulmaz.
  static func displayName(_ raw: String) -> String {
    if raw.contains(where: \.isLowercase) { return raw }
    let tr = Locale(identifier: "tr_TR")
    return raw.lowercased(with: tr)
      .split(separator: " ", omittingEmptySubsequences: false)
      .map { word in word.prefix(1).uppercased(with: tr) + word.dropFirst() }
      .joined(separator: " ")
  }

  /// Seçili konumun görünen adı (ilçe, yoksa il).
  static var selectedDisplayName: String {
    let raw = district(selectedDistrictId)?.name ?? selectedStateId.flatMap { state($0) }?.name ?? ""
    return displayName(raw)
  }

  // Dosyalar büyük (ilçeler ~800 KB); ilk kullanımda bir kez okunur.
  static let states: [State] = {
    struct File: Decodable { let data: [State] }
    return load(File.self, "states")?.data ?? []
  }()

  private static let districts: [District] = {
    struct File: Decodable { let districts: [District] }
    return load(File.self, "all-districts")?.districts ?? []
  }()

  /// Yurtdışı listesi; yalnız Türkiye dışı bir kimlik sorulunca ya da ülke listesi açılınca okunur.
  private struct World {
    var countries: [Country] = []
    var states: [State] = []
    var statesById: [String: State] = [:]
    var districtsById: [String: District] = [:]
    var districtsByState: [String: [District]] = [:]
  }

  private static let world: World = {
    struct Row: Decodable { let _id: String; let name: String; let country_id: String?; let state_id: String? }
    struct File: Decodable { let countries: [Country]; let states: [Row]; let districts: [Row] }
    guard let file = load(File.self, "world-locations") else { return World() }
    var w = World()
    w.countries = file.countries
    w.states = file.states.map { State(_id: $0._id, name: $0.name, name_en: $0.name, country_id: $0.country_id) }
    w.statesById = Dictionary(w.states.map { ($0._id, $0) }, uniquingKeysWith: { a, _ in a })
    let districts = file.districts.compactMap { r in
      r.state_id.map { District(_id: r._id, name: r.name, name_en: r.name, state_id: $0) }
    }
    w.districtsById = Dictionary(districts.map { ($0._id, $0) }, uniquingKeysWith: { a, _ in a })
    w.districtsByState = Dictionary(grouping: districts, by: \.state_id)
    return w
  }()

  private static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

/// İlçe değişince artar; vakit gösteren ekranlar yeniden yükler.
@Observable
final class LocationChanges {
  static let shared = LocationChanges()
  var nonce = 0
}
