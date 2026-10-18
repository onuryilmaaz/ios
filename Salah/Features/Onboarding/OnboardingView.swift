import SwiftUI

/// İlk açılış tanıtımı. RN anahtarı `@salah_onboarding_done` ("true"); RN'den gelen
/// kullanıcıda LegacyMigration ile taşındığı için tekrar gösterilmez.
@Observable
final class OnboardingStore {
  static let shared = OnboardingStore()
  private static let key = "@salah_onboarding_done"

  private(set) var done: Bool

  private init() {
    #if DEBUG
      if UserDefaults.standard.bool(forKey: "SalahDebugOnboarding") {
        done = false
        return
      }
    #endif
    done = LocalStore.string(Self.key) == "true"
  }

  func complete() {
    LocalStore.set("true", for: Self.key)
    done = true
  }
}

/// RN: screens/onboarding/OnboardingScreen.tsx
struct OnboardingView: View {
  @Environment(\.tokens) private var tokens

  private struct Slide: Identifiable {
    enum Kind { case info, location, notifications }
    let id: String
    let title: String
    let description: String
    let accent: Color
    let accent2: Color
    var kind = Kind.info
  }

  private static let green = Color(hex: 0x1f7356)
  private static let gold = Color(hex: 0xc48f2b)
  private static let slides: [Slide] = [
    .init(id: "1", title: "onboarding.s1.title", description: "onboarding.s1.desc", accent: green, accent2: green),
    .init(id: "2", title: "onboarding.s2.title", description: "onboarding.s2.desc", accent: gold, accent2: Color(hex: 0xd97706)),
    .init(id: "3", title: "onboarding.s3.title", description: "onboarding.s3.desc", accent: green, accent2: Color(hex: 0x4f46e5)),
    .init(id: "4", title: "onboarding.s4.title", description: "onboarding.s4.desc", accent: gold, accent2: Color(hex: 0x059669)),
    .init(id: "5", title: "onboarding.s5.title", description: "onboarding.s5.desc", accent: green, accent2: Color(hex: 0x0284c7)),
    .init(id: "8", title: "onboarding.s6.title", description: "onboarding.s6.desc", accent: gold, accent2: Color(hex: 0xdb2777)),
    .init(
      id: "9", title: "onboarding.location.title", description: "onboarding.location.desc", accent: green, accent2: Color(hex: 0x0284c7),
      kind: .location),
    .init(
      id: "10", title: "onboarding.notifications.title", description: "onboarding.notifications.desc", accent: gold,
      accent2: Color(hex: 0x9333ea), kind: .notifications),
  ]

  @State private var index: Int? = {
    #if DEBUG
      return UserDefaults.standard.integer(forKey: "SalahDebugOnboardingPage")
    #else
      return 0
    #endif
  }()
  @State private var busy = false
  @State private var granted: Set<Slide.Kind> = []

  private var current: Int { index ?? 0 }
  private var slide: Slide { Self.slides[current] }
  private var isLast: Bool { current == Self.slides.count - 1 }
  private var isPermission: Bool { slide.kind != .info }
  private var alreadyGranted: Bool { isPermission && granted.contains(slide.kind) }

  var body: some View {
    let dark = tokens.isDark
    GeometryReader { geo in
      let width = geo.size.width
      let progress = CGFloat(current) / CGFloat(Self.slides.count - 1)
      ZStack {
        (dark ? Color(hex: 0x131b17) : Color(hex: 0xf5f7f5)).ignoresSafeArea()

        // Paralaks küreler
        Circle()
          .fill(Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255).opacity(0.07))
          .frame(width: width * 0.95, height: width * 0.95)
          .position(x: width * 1.3 - width * 0.475, y: -geo.size.height * 0.16 + width * 0.475)
          .offset(x: -160 * progress)
          .ignoresSafeArea()
        Circle()
          .fill(Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255).opacity(dark ? 0.08 : 0.06))
          .frame(width: width * 0.8, height: width * 0.8)
          .position(x: -width * 0.35 + width * 0.4, y: geo.size.height * 1.1 - width * 0.4)
          .offset(x: 140 * progress)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          pager(width: width)
          controls
        }

        if !isLast && !isPermission {
          Button {
            Haptics.impact(.light)
            finish()
          } label: {
            Text(t("onboarding.skip"))
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(dark ? Forest.s300 : Forest.s500)
              .padding(.horizontal, 16)
              .padding(.vertical, 6)
              .background(dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), in: .capsule)
              .overlay(Capsule().stroke(dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("onboarding.skipIntro"))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(.top, 12)
          .padding(.trailing, 20)
        }
      }
      .animation(.easeOut(duration: 0.35), value: current)
    }
    .statusBar(.auto)
  }

  private func pager(width: CGFloat) -> some View {
    ScrollViewReader { proxy in
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(Array(Self.slides.enumerated()), id: \.offset) { i, s in
          page(s)
            .frame(width: width)
            .id(i)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $index)
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.basedOnSize)
    .onChange(of: index) { Haptics.selection() }
    // scrollPosition ilk yerleşimde başlangıç sayfasına gitmiyor (yalnız Debug'da 0'dan farklı).
    .onAppear { if current > 0 { proxy.scrollTo(current) } }
    }
  }

  private func page(_ s: Slide) -> some View {
    let dark = tokens.isDark
    return VStack(spacing: 0) {
      OnboardingArt(scene: s.id, accent: s.accent, accent2: s.accent2, isDark: dark)
        .scrollTransition(axis: .horizontal) { content, phase in
          content
            .opacity(1 - abs(phase.value))
            .scaleEffect(1 - 0.4 * abs(phase.value))
            .offset(x: phase.value * 70)
        }
        .padding(.bottom, 44)
      Text(t(s.title))
        .font(.system(size: 30, weight: .black))
        .tracking(-0.5)
        .foregroundStyle(dark ? Color(hex: 0xf5f7f5) : Color(hex: 0x222d28))
        .multilineTextAlignment(.center)
        .padding(.bottom, 16)
        .scrollTransition(axis: .horizontal) { content, phase in
          content.opacity(1 - abs(phase.value)).offset(y: 40 * abs(phase.value))
        }
      Text(t(s.description))
        .font(.system(size: 15.5))
        .lineSpacing(25 - 15.5 * 1.2)
        .foregroundStyle(dark ? Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255).opacity(0.58) : Color(hex: 0x6a766f))
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)
        .scrollTransition(axis: .horizontal) { content, phase in
          content.opacity(1 - abs(phase.value)).offset(y: 64 * abs(phase.value))
        }
    }
    .padding(.horizontal, 32)
    .frame(maxHeight: .infinity)
  }

  private var controls: some View {
    let ctaLabel =
      alreadyGranted
      ? t("onboarding.continue")
      : slide.kind == .location
        ? t("onboarding.allowLocation")
        : slide.kind == .notifications ? t("onboarding.allowNotifications") : isLast ? t("onboarding.start") : t("onboarding.next")
    let ctaIcon = alreadyGranted ? "checkmark-circle" : isPermission ? "shield-checkmark" : isLast ? "sparkles" : dirIcon("arrow-forward")

    return VStack(spacing: 0) {
      HStack(spacing: 7) {
        ForEach(Array(Self.slides.enumerated()), id: \.offset) { i, _ in
          Button {
            withAnimation { index = i }
          } label: {
            RoundedRectangle(cornerRadius: 4)
              .fill(slide.accent)
              .frame(width: i == current ? 28 : 7, height: 7)
              .opacity(i == current ? 1 : 0.28)
              .padding(.vertical, 14)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(t("onboarding.slideA11y", ["n": i + 1, "total": Self.slides.count]))
          .accessibilityAddTraits(i == current ? .isSelected : [])
        }
      }
      .padding(.bottom, 14)

      Button(action: next) {
        HStack(spacing: 8) {
          Text(ctaLabel)
            .font(.system(size: 16.5, weight: .black))
            .tracking(0.3)
          Ionicon(ctaIcon, size: 20, color: .white)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .background(
          LinearGradient(colors: [slide.accent, slide.accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
          in: .rect(cornerRadius: 22)
        )
        .shadow(color: slide.accent.opacity(0.45), radius: 9, y: 10)
        .opacity(busy ? 0.7 : 1)
      }
      .buttonStyle(PressableStyle(pressedOpacity: 0.9))
      .disabled(busy)
      .accessibilityLabel(ctaLabel)

      if isPermission && !alreadyGranted {
        Button {
          Haptics.impact(.light)
          goNext()
        } label: {
          Text(t("onboarding.skipForNow"))
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tokens.isDark ? Forest.s500 : Forest.s400)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.6))
        .padding(.top, 14)
      } else {
        Color.clear.frame(height: 26).padding(.top, 14)
      }
    }
    .padding(.horizontal, 28)
    .padding(.top, 4)
    .padding(.bottom, 22)
  }

  // MARK: - Akış

  private func next() {
    Haptics.impact(.medium)
    if slide.kind == .location && !granted.contains(.location) {
      Task { await requestLocation() }
    } else if slide.kind == .notifications && !granted.contains(.notifications) {
      Task { await requestNotifications() }
    } else {
      goNext()
    }
  }

  private func goNext() {
    if current < Self.slides.count - 1 {
      withAnimation { index = current + 1 }
    } else {
      finish()
    }
  }

  private func finish() {
    withAnimation(.easeOut(duration: 0.3)) { OnboardingStore.shared.complete() }
  }

  /// İzin verilirse konumdan il ve varsayılan ilçesi seçilir; bulunamazsa sonradan elle seçilir.
  private func requestLocation() async {
    busy = true
    defer {
      busy = false
      goNext()
    }
    do {
      let found = try await LocationService.shared.detectDistrict()
      Locations.select(stateId: found.state._id, districtId: found.district._id, source: "auto")
      Haptics.notify(.success)
      granted.insert(.location)
    } catch LocationService.Failure.denied {
      Haptics.notify(.warning)
    } catch {
      // İzin verildi ama il bulunamadı: RN'deki gibi izin verilmiş sayılır.
      Haptics.notify(.success)
      granted.insert(.location)
    }
  }

  private func requestNotifications() async {
    busy = true
    defer {
      busy = false
      goNext()
    }
    if await NotificationStore.shared.setEnabled(true) {
      Haptics.notify(.success)
      granted.insert(.notifications)
    } else {
      Haptics.notify(.warning)
    }
  }
}
