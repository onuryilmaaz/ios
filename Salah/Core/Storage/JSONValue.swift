import Foundation

/// Biçimi serbest JSON (istek gövdeleri, kuyruk kayıtları, rozet listeleri).
enum JSONValue: Codable, Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let v = try? c.decode(Bool.self) {
      self = .bool(v)
    } else if let v = try? c.decode(Double.self) {
      self = .number(v)
    } else if let v = try? c.decode(String.self) {
      self = .string(v)
    } else if let v = try? c.decode([JSONValue].self) {
      self = .array(v)
    } else {
      self = .object(try c.decode([String: JSONValue].self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    }
  }

  subscript(key: String) -> JSONValue? {
    if case .object(let o) = self { return o[key] }
    return nil
  }

  var stringValue: String? {
    if case .string(let v) = self { return v }
    return nil
  }

  /// Sayı ya da sayı içeren metin (backend bazı sayaçları metin döndürüyor).
  var intValue: Int? {
    switch self {
    case .number(let v): return Int(v)
    case .string(let v): return Int(v)
    default: return nil
    }
  }

  var boolValue: Bool? {
    if case .bool(let v) = self { return v }
    return nil
  }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral,
  ExpressibleByDictionaryLiteral
{
  init(stringLiteral value: String) { self = .string(value) }
  init(booleanLiteral value: Bool) { self = .bool(value) }
  init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}
