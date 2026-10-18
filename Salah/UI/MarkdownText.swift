import SwiftUI

/// AI cevapları için hafif markdown ayrıştırıcı. RN: utils/markdown.ts (aynı kurallar):
/// başlık (#), madde (-, *, •), numaralı liste (1.), kalın (**…**, __…__),
/// italik (*…*, _…_) ve paragraflar.
nonisolated enum Markdown {
  enum Block: Equatable {
    case heading(String)
    case paragraph(String)
    case bullet(String)
    case number(marker: String, text: String)
  }

  struct Span: Equatable {
    var text: String
    var bold = false
    var italic = false
  }

  static func blocks(_ input: String) -> [Block] {
    var out: [Block] = []
    var paragraph: [String] = []
    func flush() {
      if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))) }
      paragraph = []
    }
    for raw in input.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty {
        flush()
      } else if let m = match(#"^#{1,6}\s+(.*)$"#, line) {
        flush()
        out.append(.heading(m[1]))
      } else if let m = match(#"^[-*•]\s+(.*)$"#, line) {
        flush()
        out.append(.bullet(m[1]))
      } else if let m = match(#"^(\d+)[.)]\s+(.*)$"#, line) {
        flush()
        out.append(.number(marker: "\(m[1]).", text: m[2]))
      } else {
        paragraph.append(line)
      }
    }
    flush()
    return out
  }

  /// Eşleşmeyen işaret (ör. "5 * 3") ve kelime içi alt çizgi metin kalır.
  static func inline(_ text: String) -> [Span] {
    let pattern = #"(\*\*|__)(.+?)\1|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?!\w)|(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?!\w)"#
    guard let re = try? NSRegularExpression(pattern: pattern) else { return [Span(text: text)] }
    let ns = text as NSString
    var spans: [Span] = []
    var last = 0
    for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      if m.range.location > last { spans.append(Span(text: ns.substring(with: NSRange(location: last, length: m.range.location - last)))) }
      if m.range(at: 2).location != NSNotFound {
        spans.append(Span(text: ns.substring(with: m.range(at: 2)), bold: true))
      } else {
        let r = m.range(at: 3).location != NSNotFound ? m.range(at: 3) : m.range(at: 4)
        spans.append(Span(text: ns.substring(with: r), italic: true))
      }
      last = m.range.location + m.range.length
    }
    if last < ns.length { spans.append(Span(text: ns.substring(from: last))) }
    return spans.filter { !$0.text.isEmpty }
  }

  /// Kopyalama/paylaşım için işaretsiz düz metin.
  static func strip(_ input: String) -> String {
    blocks(input).map { block in
      func plain(_ s: String) -> String { inline(s).map(\.text).joined() }
      switch block {
      case .heading(let t), .paragraph(let t): return plain(t)
      case .bullet(let t): return "• \(plain(t))"
      case .number(let marker, let t): return "\(marker) \(plain(t))"
      }
    }.joined(separator: "\n")
  }

  private static func match(_ pattern: String, _ text: String) -> [String]? {
    guard let re = try? NSRegularExpression(pattern: pattern),
      let m = re.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    else { return nil }
    return (0..<m.numberOfRanges).map { i in
      let r = m.range(at: i)
      return r.location == NSNotFound ? "" : (text as NSString).substring(with: r)
    }
  }
}

/// Biçimli AI metni. RN: components/ui/MarkdownText.tsx
struct MarkdownText: View {
  let text: String
  var size: CGFloat = 15
  var color: Color
  var italic = false
  var lineSpacing: CGFloat = 4

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(Markdown.blocks(text).enumerated()), id: \.offset) { _, block in
        switch block {
        case .heading(let t):
          styled(t).fontWeight(.semibold)
        case .paragraph(let t):
          styled(t)
        case .bullet(let t):
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: "•").frame(width: 16, alignment: .leading)
            styled(t)
          }
          .font(.system(size: size)).foregroundStyle(color)
        case .number(let marker, let t):
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(marker).frame(minWidth: 22, alignment: .leading)
            styled(t)
          }
          .font(.system(size: size)).foregroundStyle(color)
        }
      }
    }
  }

  private func styled(_ value: String) -> Text {
    Markdown.inline(value).reduce(Text(verbatim: "")) { result, span in
      var piece = Text(span.text)
      if span.bold { piece = piece.fontWeight(.semibold) }
      if span.italic || italic { piece = piece.italic() }
      return result + piece
    }
    .font(.system(size: size))
    .foregroundColor(color)
  }
}
