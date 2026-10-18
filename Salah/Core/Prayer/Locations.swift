import Foundation

/// İl/ilçe verisi; RN ile ortak dosyalar (mobile/src/constants/states.json,
/// all-districts.json). Seçim RN ile aynı anahtarlarda tutulur.
enum Locations {
  struct State: Decodable, Sendable {
    let _id: String
    let name: String
    let name_en: String
  }

  struct District: Decodable, Sendable {
    let _id: String
    let name: String
    let name_en: String
    let state_id: String
  }

  static let districtIdKey = "SELECTED_DISTRICT_ID"
  static let stateIdKey = "SELECTED_STATE_ID"
  static let sourceKey = "SELECTED_DISTRICT_SOURCE"

  static var selectedDistrictId: String {
    LocalStore.string(districtIdKey) ?? PrayerTimesService.defaultDistrictId
  }

  static var selectedStateId: String? { LocalStore.string(stateIdKey) }

  static func state(_ id: String) -> State? { states.first { $0._id == id } }
  static func districts(ofState id: String) -> [District] { districts.filter { $0.state_id == id } }

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

  /// Seçimi kaydeder (RN ile aynı anahtarlar) ve ekranlara yeniden okuma sinyali verir.
  /// - Parameter source: "manual" (kullanıcı seçti) ya da "auto" (konumdan bulundu).
  static func select(stateId: String, districtId: String, source: String) {
    LocalStore.set(stateId, for: stateIdKey)
    LocalStore.set(districtId, for: districtIdKey)
    LocalStore.set(source, for: sourceKey)
    LocationChanges.shared.nonce += 1
  }
  static func district(_ id: String) -> District? { districts.first { $0._id == id } }

  /// Veri büyük harfle gelir ("KOCAELİ"); Türkçe kurallarına göre "Kocaeli" yapar.
  static func displayName(_ raw: String) -> String {
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
