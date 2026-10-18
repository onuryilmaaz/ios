import SwiftUI

/// Kısa süreli, işlem gerektirmeyen bildirim (3 sn). Onay ya da önemli hata için `AppAlert`.
/// RN: components/feedback/Toast.tsx
enum Toast {
  enum Kind { case success, error, warning, info }

  static func success(_ title: String, _ message: String? = nil) { ToastCenter.shared.show(.success, title, message) }
  static func error(_ title: String, _ message: String? = nil) { ToastCenter.shared.show(.error, title, message) }
  static func warning(_ title: String, _ message: String? = nil) { ToastCenter.shared.show(.warning, title, message) }
  static func info(_ title: String, _ message: String? = nil) { ToastCenter.shared.show(.info, title, message) }
}

@Observable
final class ToastCenter {
  static let shared = ToastCenter()

  struct Item: Identifiable, Equatable {
    let id = UUID()
    let kind: Toast.Kind
    let title: String
    let message: String?
  }

  private(set) var items: [Item] = []
  @ObservationIgnored private lazy var window = OverlayWindow(level: .statusBar) { ToastHost() }

  func show(_ kind: Toast.Kind, _ title: String, _ message: String?) {
    let item = Item(kind: kind, title: title, message: message)
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { items.append(item) }
    window.show()
    Task {
      try? await Task.sleep(for: .seconds(3))
      dismiss(item.id)
    }
  }

  func dismiss(_ id: UUID) {
    withAnimation(.easeIn(duration: 0.2)) { items.removeAll { $0.id == id } }
    if items.isEmpty {
      Task {
        try? await Task.sleep(for: .milliseconds(250))
        if items.isEmpty { window.hide() }
      }
    }
  }
}

private struct ToastHost: View {
  var body: some View {
    VStack(spacing: 7) {
      ForEach(ToastCenter.shared.items) { item in
        ToastRow(item: item)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
      Spacer()
    }
    .padding(.top, 4)
    // Yalnız kartlar dokunmayı yakalar; boş alan alttaki uygulamaya geçer.
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

private struct ToastRow: View {
  @Environment(\.tokens) private var tokens
  let item: ToastCenter.Item

  var body: some View {
    HStack(spacing: 10.5) {
      Ionicon(icon, size: 22, color: iconColor)
      VStack(alignment: .leading, spacing: 1.75) {
        Text(item.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(tokens.textPrimary)
          .lineLimit(1)
        if let message = item.message {
          Text(message)
            .font(.system(size: 13))
            .foregroundStyle(tokens.textSecondary)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        ToastCenter.shared.dismiss(item.id)
      } label: {
        Ionicon("close", size: 18, color: tokens.inkSubtle).frame(width: 24.5, height: 24.5)
      }
      .buttonStyle(PressableStyle())
      .accessibilityLabel(t("common.close"))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10.5)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    // Yüzen öğe: tasarım dilindeki tek gölge istisnası.
    .shadow(color: .black.opacity(tokens.isDark ? 0.4 : 0.08), radius: 8, y: 6)
    .padding(.horizontal, 14)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var icon: String {
    switch item.kind {
    case .success: "checkmark-circle"
    case .error: "alert-circle"
    case .warning: "warning"
    case .info: "information-circle"
    }
  }

  private var iconColor: Color {
    switch item.kind {
    case .success: tokens.accent
    case .error: tokens.danger
    case .warning: tokens.isDark ? Amber.s400 : Amber.s600
    case .info: tokens.inkMuted
    }
  }
}

/// Dosya yüklerken tam ekran kaplama. RN: components/feedback/UploadOverlay.tsx
struct UploadOverlay: View {
  @Environment(\.tokens) private var tokens
  var message: String?
  @State private var spinning = false
  @State private var pulse = false
  @State private var dotPhase = 0

  var body: some View {
    let dark = tokens.isDark
    ZStack {
      Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
      VStack(spacing: 0) {
        ZStack {
          Circle().fill(dark ? Accent.s500.opacity(0.1) : Accent.s100.opacity(0.5))
            .frame(width: 98, height: 98)
            .scaleEffect(pulse ? 1.1 : 1)
          ZStack {
            Circle().stroke(dark ? Forest.s800 : Forest.s100, lineWidth: 4)
            Circle().trim(from: 0, to: 0.25).stroke(dark ? Accent.s400 : Accent.s600, style: StrokeStyle(lineWidth: 4, lineCap: .round))
              .rotationEffect(.degrees(spinning ? 360 : 0))
            Ionicon("cloud-upload", size: 24, color: dark ? Accent.s400 : Accent.s600)
              .frame(width: 42, height: 42)
              .background(dark ? Accent.s500.opacity(0.2) : Accent.s50, in: .circle)
          }
          .frame(width: 70, height: 70)
        }
        .frame(height: 70)
        .padding(.bottom, 21)

        Text(message ?? t("upload.loading"))
          .font(.system(size: 15.75, weight: .bold))
          .foregroundStyle(dark ? .white : Forest.s900)
          .multilineTextAlignment(.center)
        Text(t("upload.wait"))
          .font(.system(size: 12.25))
          .foregroundStyle(dark ? Forest.s300 : Forest.s500)
          .padding(.top, 3.5)

        HStack(spacing: 7) {
          ForEach(0..<3, id: \.self) { i in
            Circle().fill(dark ? Accent.s400 : Accent.s600)
              .frame(width: 7, height: 7)
              .opacity(dotPhase == i ? 1 : 0.3)
          }
        }
        .padding(.top, 21)
      }
      .padding(.horizontal, 42)
      .padding(.vertical, 35)
      .background(dark ? Forest.s800.opacity(0.7) : .white, in: .rect(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1))
    }
    .onAppear {
      withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { spinning = true }
      withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true }
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(200))
        dotPhase = (dotPhase + 1) % 3
      }
    }
  }
}
