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
    /// Lottie sahnesi: `Shared/mobile/assets/lottie/onboarding_<scene>.json`.
    let scene: String
    var kind = Kind.info
  }

  private static let slides: [Slide] = {
    var list: [Slide] = [
      .init(id: "welcome", title: "onboarding.s1.title", description: "onboarding.s1.desc", scene: "welcome"),
      .init(id: "times", title: "onboarding.times.title", description: "onboarding.times.desc", scene: "times"),
      .init(id: "quran", title: "onboarding.quran.title", description: "onboarding.quran.desc", scene: "quran"),
      .init(id: "tracker", title: "onboarding.tracker.title", description: "onboarding.tracker.desc", scene: "tracker"),
      .init(id: "tools", title: "onboarding.tools.title", description: "onboarding.tools.desc", scene: "tools"),
    ]
    #if PRAYER_LOCK
    // Yalnız iOS; panelden kapatıldıysa (önbellekteki ayar) gösterilmez.
    if AppControlStore.shared.isOn("prayer_lock") {
      list.append(.init(id: "prayerLock", title: "onboarding.prayerLock.title", description: "onboarding.prayerLock.desc", scene: "prayerLock"))
    }
    #endif
    list.append(.init(id: "location", title: "onboarding.location.title", description: "onboarding.location.desc", scene: "location", kind: .location))
    list.append(
      .init(id: "notifications", title: "onboarding.notifications.title", description: "onboarding.notifications.desc", scene: "notifications", kind: .notifications))
    return list
  }()

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
    GeometryReader { geo in
      let width = geo.size.width
      ZStack {
        tokens.canvas.ignoresSafeArea()

        VStack(spacing: 0) {
          pager(width: width, height: geo.size.height)
          controls
        }

        if !isLast && !isPermission {
          Button {
            Haptics.impact(.light)
            skipIntro()
          } label: {
            Text(t("onboarding.skip"))
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(tokens.textSecondary)
              .padding(.horizontal, 14)
              .padding(.vertical, 7)
              .background(tokens.surface, in: .capsule)
              .overlay(Capsule().stroke(tokens.line, lineWidth: 1))
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
    .onAppear { UsageStore.shared.record("onboarding.start") }
  }

  private func pager(width: CGFloat, height: CGFloat) -> some View {
    ScrollViewReader { proxy in
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(Array(Self.slides.enumerated()), id: \.offset) { i, s in
          page(s, active: i == current, art: min(width - 64, height * 0.36, 300))
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

  private func page(_ s: Slide, active: Bool, art: CGFloat) -> some View {
    VStack(spacing: 0) {
      SceneAnimation(scene: s.scene, active: active)
        .frame(width: art, height: art)
        .scrollTransition(axis: .horizontal) { content, phase in
          content
            .opacity(1 - abs(phase.value))
            .scaleEffect(1 - 0.25 * abs(phase.value))
            .offset(x: phase.value * 60)
        }
        .padding(.bottom, 36)
      Text(t(s.title))
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(tokens.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 12)
        .scrollTransition(axis: .horizontal) { content, phase in
          content.opacity(1 - abs(phase.value)).offset(y: 30 * abs(phase.value))
        }
      Text(t(s.description))
        .font(.system(size: 15))
        .lineSpacing(5)
        .foregroundStyle(tokens.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 340)
        .scrollTransition(axis: .horizontal) { content, phase in
          content.opacity(1 - abs(phase.value)).offset(y: 48 * abs(phase.value))
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
            Capsule()
              .fill(i == current ? tokens.accent : tokens.line)
              .frame(width: i == current ? 24 : 7, height: 7)
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
            .font(.system(size: 16, weight: .semibold))
          Ionicon(ctaIcon, size: 19, color: tokens.onAccent)
        }
        .foregroundStyle(tokens.onAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(tokens.accent, in: .capsule)
        .opacity(busy ? 0.7 : 1)
      }
      .buttonStyle(PressableStyle(pressedOpacity: 0.9))
      .disabled(busy)
      .accessibilityLabel(ctaLabel)

      if isPermission && !alreadyGranted {
        Button {
          Haptics.impact(.light)
          UsageStore.shared.record("onboarding.\(slide.kind == .location ? "location" : "notifications").later")
          goNext()
        } label: {
          Text(t("onboarding.skipForNow"))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tokens.textSecondary)
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

  /// "Atla": tanıtım geçilir ama izin sayfaları atlanmaz (konum ve bildirim sorulmadan ana sayfaya düşülmesin).
  private func skipIntro() {
    UsageStore.shared.record("onboarding.skip")
    if let first = Self.slides.firstIndex(where: { $0.kind != .info }), first > current {
      withAnimation { index = first }
    } else {
      finish()
    }
  }

  private func finish() {
    UsageStore.shared.record("onboarding.done")
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
      UsageStore.shared.record("onboarding.location.granted")
    } catch LocationService.Failure.denied {
      Haptics.notify(.warning)
      UsageStore.shared.record("onboarding.location.denied")
    } catch {
      // İzin verildi ama il bulunamadı: RN'deki gibi izin verilmiş sayılır.
      Haptics.notify(.success)
      granted.insert(.location)
      UsageStore.shared.record("onboarding.location.granted")
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
      UsageStore.shared.record("onboarding.notifications.granted")
    } else {
      Haptics.notify(.warning)
      UsageStore.shared.record("onboarding.notifications.denied")
    }
  }
}
