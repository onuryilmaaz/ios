import SwiftUI

/// Uygulama rengi seçimi: dört hazır renk ve paletten seçilen özel renk. Ramazan'da renk saate göre kendiliğinden
/// değişir; seçim yine kaydedilir.
struct AppColorPicker: View {
  @Environment(\.tokens) private var tokens
  @State private var customOpen = false

  var body: some View {
    let store = AppColorStore.shared
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(t("appColor.title")).padding(.leading, 10.5)
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          ForEach(Array(AppColor.presets.enumerated()), id: \.element) { i, color in
            if i > 0 { Spacer(minLength: 0) }
            swatch(color, selected: color == store.choice)
          }
          Spacer(minLength: 0)
          customSwatch(selected: store.choice == .custom)
        }
        Text(t("appColor.ramadanHint"))
          .font(.system(size: 13))
          .foregroundStyle(tokens.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
      .padding(.bottom, 21)
    }
    #if DEBUG
    .onAppear { if UserDefaults.standard.bool(forKey: "SalahDebugColorSheet") { customOpen = true } }
    #endif
    .sheet(isPresented: $customOpen) {
      CustomColorSheet().environment(\.tokens, tokens).presentationDetents([.large]).presentationDragIndicator(.visible)
    }
  }

  private func swatch(_ color: AppColor, selected: Bool) -> some View {
    let scale = color.scales.accent
    return Button {
      guard !selected else { return }
      Haptics.impact(.light)
      AppColorStore.shared.set(color)
    } label: {
      VStack(spacing: 7) {
        ZStack {
          Circle().fill(Color(hex: scale[9]))
          Circle().fill(Color(hex: scale[4])).frame(width: 18, height: 18).opacity(selected ? 0 : 1)
          if selected { Ionicon("checkmark", size: 20, color: Gold.s300) }
        }
        .frame(width: 45, height: 45)
        .padding(3)
        .overlay(Circle().stroke(selected ? Gold.s400 : .clear, lineWidth: 2))
        Text(t("appColor.\(color.rawValue)"))
          .font(.system(size: 12, weight: selected ? .semibold : .regular))
          .foregroundStyle(selected ? tokens.textPrimary : tokens.textSecondary)
      }
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t("appColor.\(color.rawValue)"))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// Özel renk: seçiliyken kendi tonu, değilken palet simgesi; dokununca palet açılır.
  private func customSwatch(selected: Bool) -> some View {
    let scale = AppColor.custom.scales.accent
    return Button {
      Haptics.impact(.light)
      customOpen = true
    } label: {
      VStack(spacing: 7) {
        ZStack {
          Circle().fill(selected ? Color(hex: scale[9]) : tokens.fill)
          if selected { Ionicon("checkmark", size: 20, color: Gold.s300) }
          else { Ionicon("color-palette-outline", size: 20, color: tokens.inkMuted) }
        }
        .frame(width: 45, height: 45)
        .padding(3)
        .overlay(Circle().stroke(selected ? Gold.s400 : .clear, lineWidth: 2))
        Text(t("appColor.custom"))
          .font(.system(size: 12, weight: selected ? .semibold : .regular))
          .foregroundStyle(selected ? tokens.textPrimary : tokens.textSecondary)
      }
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(t("appColor.customTitle"))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Paletten seçilen renk: tekerlek, renk kodu ve önizleme; "Uygula" ile kaydedilir.
private struct CustomColorSheet: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var seed: UInt32 = AppColor.customSeed
  @State private var hex = CustomPalette.format(AppColor.customSeed)
  @State private var hexError: String?

  var body: some View {
    let scales = CustomPalette.scales(seed: seed)
    VStack(spacing: 0) {
      HStack {
        Text(t("appColor.customTitle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Button { Haptics.impact(.light); dismiss() } label: {
          Ionicon("close", size: 20, color: tokens.inkMuted).frame(width: 35, height: 35).background(tokens.surface, in: .circle)
            .overlay(Circle().stroke(tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle()).accessibilityLabel(t("common.close"))
      }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(t("appColor.customHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
          preview(scales)
          ColorWheel(seed: $seed) { hex = CustomPalette.format($0); hexError = nil }
            .frame(maxWidth: .infinity)
          InputField(label: t("appColor.hexLabel"), placeholder: "#1F7356", text: $hex, error: hexError, maxLength: 7)
            .onChange(of: hex) { _, value in
              if let v = CustomPalette.parse(value) { seed = v; hexError = nil }
            }
          AppButton(title: t("appColor.apply")) {
            guard let v = CustomPalette.parse(hex) else {
              Haptics.notify(.error)
              hexError = t("appColor.hexInvalid")
              return
            }
            Haptics.notify(.success)
            AppColorStore.shared.setCustom(v)
            dismiss()
          }
        }
        .padding(16).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
  }

  /// Seçilen rengin kahraman kartı, düğmesi ve ölçeği.
  private func preview(_ scales: (accent: [UInt32], neutral: [UInt32])) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(t("appColor.preview")).font(.system(size: 13, weight: .medium)).foregroundStyle(Gold.s300)
      HStack(spacing: 4) {
        ForEach(0..<11, id: \.self) { i in
          RoundedRectangle(cornerRadius: 4).fill(Color(hex: scales.accent[i])).frame(height: 18)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.18), lineWidth: 1))
        }
      }
      Text(t("appColor.sampleButton"))
        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(hex: scales.accent[6]), in: .capsule)
    }
    .padding(17.5)
    .background(Color(hex: scales.accent[9]), in: .rect(cornerRadius: 24))
  }
}

/// Renk tekerleği: açı ton, merkezden uzaklık doygunluk (merkez gri, kenar 0,12). Her nokta uygulamanın accent-600
/// tonunu gösterir; seçilen nokta ile uygulamada çıkan renk aynıdır. Görüntü bir kez arka planda çizilir.
struct ColorWheel: View {
  @Environment(\.tokens) private var tokens
  @Binding var seed: UInt32
  var onPick: (UInt32) -> Void
  @State private var image: CGImage? = ColorWheel.cached
  @State private var dragging = false

  private static var cached: CGImage?
  nonisolated private static let pixels = 480
  nonisolated static let maxChroma = 0.12

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      let radius = size / 2
      let (_, c, h) = CustomPalette.oklch(seed)
      let r = min(1, c / Self.maxChroma) * radius
      let thumb = CGPoint(x: radius + cos(h * .pi / 180) * r, y: radius - sin(h * .pi / 180) * r)
      ZStack {
        if let image {
          Image(decorative: image, scale: 1).resizable().interpolation(.high)
            .frame(width: size, height: size).clipShape(Circle())
        } else {
          Circle().fill(tokens.fill).frame(width: size, height: size)
        }
        Circle()
          .fill(Color(hex: seed))
          .frame(width: dragging ? 40 : 30, height: dragging ? 40 : 30)
          .overlay(Circle().stroke(.white, lineWidth: 3))
          .overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 1).padding(-1.5))
          .position(thumb)
          .animation(.easeOut(duration: 0.15), value: dragging)
      }
      .frame(width: size, height: size)
      .contentShape(Circle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if !dragging { dragging = true; Haptics.impact(.light) }
            pick(at: value.location, radius: radius)
          }
          .onEnded { _ in dragging = false; Haptics.impact(.light) }
      )
      .frame(maxWidth: .infinity)
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: 300)
    .accessibilityElement()
    .accessibilityLabel(t("appColor.wheel"))
    .accessibilityValue(CustomPalette.format(seed))
    .accessibilityAdjustableAction { direction in
      let (_, c, h) = CustomPalette.oklch(seed)
      let next = h + (direction == .increment ? 15 : -15)
      set(CustomPalette.toRGB(l: CustomPalette.accentL[6], c: max(c, 0.06), h: next))
    }
    .task {
      guard image == nil else { return }
      let rendered = await Task.detached(priority: .userInitiated) { Self.render(Self.pixels) }.value
      Self.cached = rendered
      image = rendered
    }
  }

  private func pick(at p: CGPoint, radius: CGFloat) {
    let dx = p.x - radius, dy = radius - p.y
    let r = min(1, sqrt(dx * dx + dy * dy) / radius)
    var h = atan2(dy, dx) * 180 / .pi
    if h < 0 { h += 360 }
    set(CustomPalette.toRGB(l: CustomPalette.accentL[6], c: r * Self.maxChroma, h: h))
  }

  private func set(_ value: UInt32) {
    guard value != seed else { return }
    seed = value
    onPick(value)
  }

  nonisolated static func render(_ n: Int) -> CGImage? {
    var data = [UInt8](repeating: 0, count: n * n * 4)
    let half = Double(n) / 2
    let l = CustomPalette.accentL[6]
    for y in 0..<n {
      for x in 0..<n {
        let dx = (Double(x) + 0.5 - half) / half, dy = (half - Double(y) - 0.5) / half
        let r = (dx * dx + dy * dy).squareRoot()
        guard r <= 1.02 else { continue }
        var h = atan2(dy, dx) * 180 / .pi
        if h < 0 { h += 360 }
        let rgb = CustomPalette.toRGB(l: l, c: min(1, r) * maxChroma, h: h)
        let i = (y * n + x) * 4
        data[i] = UInt8((rgb >> 16) & 0xFF)
        data[i + 1] = UInt8((rgb >> 8) & 0xFF)
        data[i + 2] = UInt8(rgb & 0xFF)
        data[i + 3] = 255
      }
    }
    guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
    return CGImage(
      width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
    )
  }
}
