import SwiftUI

// Yönetim paneli. RN: screens/admin/* ve modules/admin/admin.api.ts.
// Metinler RN'deki gibi yalnız Türkçe (CLAUDE.md: admin ekranları çevrilmez).

struct AdminUser: Decodable, Identifiable, Equatable {
  let id: String
  let email: String
  var username: String?
  var roles: [String]?
  var firstName: String?
  var lastName: String?
  var isActive: Bool?
  var isPremium: Bool?
  var premiumUntil: String?
  var avatarUrl: String?
}

struct AdminRole: Decodable, Identifiable, Equatable {
  let id: String
  let name: String
}

enum AdminAPI {
  struct UserList: Decodable {
    let users: [AdminUser]
    let total: Int
    let page: Int
    let totalPages: Int
  }

  /// `[...]` ya da `{ roles: [...] }`.
  static func roles() async throws -> [AdminRole] {
    let data = try await send("GET", "/admin/roles")
    return try decodeRoles(data)
  }

  static func decodeRoles(_ data: Data) throws -> [AdminRole] {
    struct Wrapped: Decodable { let roles: [AdminRole] }
    if let list = try? JSONDecoder().decode([AdminRole].self, from: data) { return list }
    return try JSONDecoder().decode(Wrapped.self, from: data).roles
  }

  /// `{...}` ya da `{ user: {...} }`.
  static func user(_ id: String) async throws -> AdminUser {
    let data = try await send("GET", "/admin/users/\(encode(id))")
    return try decodeUser(data)
  }

  static func decodeUser(_ data: Data) throws -> AdminUser {
    struct Wrapped: Decodable { let user: AdminUser }
    if let w = try? JSONDecoder().decode(Wrapped.self, from: data) { return w.user }
    return try JSONDecoder().decode(AdminUser.self, from: data)
  }

  static func sessionCount(_ id: String) async -> Int {
    guard let data = try? await send("GET", "/admin/users/\(encode(id))/sessions"),
      let value = try? JSONDecoder().decode(JSONValue.self, from: data)
    else { return 0 }
    if case .array(let list) = value { return list.count }
    if case .array(let list)? = value["sessions"] { return list.count }
    return 0
  }

  static func encode(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
  }

  static func users(page: Int, search: String) async throws -> UserList {
    var path = "/admin/users?page=\(page)&limit=20"
    if !search.isEmpty { path += "&search=\(encode(String(search.prefix(100))))" }
    return try JSONDecoder().decode(UserList.self, from: await send("GET", path))
  }

  @discardableResult
  static func send(_ method: String, _ path: String, body: JSONValue? = nil) async throws -> Data {
    #if DEBUG
    if DebugLaunch.adminPreview { return try AdminPreview.response(method, path) }
    #endif
    guard AuthStore.shared.user?.roles?.contains("admin") == true else {
      throw APIError.http(status: 403, body: Data())
    }
    return try await APIClient.shared.send(method, path, body: body)
  }
}

/// RN Dashboard ve kart içi ekran ortak kabuğu.
private struct AdminScreen<Content: View>: View {
  @Environment(\.tokens) private var tokens
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: title)
      if AuthStore.shared.user?.roles?.contains("admin") == true || DebugLaunch.adminPreview {
        content
      } else {
        Spacer()
        EmptyState(icon: "lock-closed-outline", title: "Erişim Yok", message: "Bu ekran için yönetici yetkisi gerekiyor.")
        Spacer()
      }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }
}

private let red = Color(hex: 0xdc2626)

// MARK: - Panel

struct AdminDashboardView: View {
  @Environment(\.tokens) private var tokens
  @State private var stats: JSONValue?
  @State private var loading = true
  @State private var failed = false

  var body: some View {
    AdminScreen(title: "Admin Paneli") {
      if loading && stats == nil {
        Spacer()
        ProgressView("Dashboard yükleniyor...").tint(tokens.accent)
        Spacer()
      } else if failed && stats == nil {
        Spacer()
        EmptyState(icon: "cloud-offline-outline", title: "Yükleme Hatası", message: "İstatistikler alınamadı") {
          AppButton(title: "Tekrar Dene") { Task { await load() } }.frame(width: 180)
        }
        Spacer()
      } else {
        ScrollView {
          VStack(spacing: 14) {
            if let users = stats?["users"] { summary(users) }
            Card {
              Text("Yönetim").font(.system(size: 14, weight: .bold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 10.5)
              VStack(spacing: 7) {
                menu("people-outline", "Kullanıcılar", "Kullanıcıları görüntüle ve yönet", Color(hex: 0x3b82f6), .adminUsers)
                menu("key-outline", "Roller", "Sistem rollerini yönet", Color(hex: 0xf59e0b), .adminRoles)
              }
            }
          }
          .padding(14)
          .padding(.bottom, 84)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
      }
    }
    .task { await load() }
  }

  private func summary(_ users: JSONValue) -> some View {
    let dark = tokens.isDark
    let green = Color(hex: 0x16a34a)
    let purple = Color(hex: 0x9333ea)
    return Card {
      Text("Özet İstatistikler").font(.system(size: 14, weight: .bold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 10.5)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10.5), GridItem(.flexible())], spacing: 10.5) {
        tile("people", "Toplam Kullanıcı", users["total"]?.intValue ?? 0, icon: tokens.accent, value: tokens.textPrimary, bg: dark ? Forest.s900 : Forest.s50)
        tile("person", "Aktif", users["active"]?.intValue ?? 0, icon: green, value: dark ? Color(hex: 0x22c55e) : Color(hex: 0x15803d), bg: dark ? Color(hex: 0x22c55e).opacity(0.1) : Color(hex: 0xf0fdf4))
        tile("person-outline", "Pasif", users["inactive"]?.intValue ?? 0, icon: Forest.s500, value: dark ? Forest.s400 : Forest.s600, bg: dark ? Color(hex: 0x374151) : Forest.s100)
        if let sessions = stats?["sessions"] {
          tile("time", "Aktif Oturum", sessions["active"]?.intValue ?? 0, icon: purple, value: dark ? Color(hex: 0xc084fc) : Color(hex: 0x7e22ce), bg: dark ? Color(hex: 0xa855f7).opacity(0.1) : Color(hex: 0xfaf5ff))
        }
      }
    }
  }

  private func tile(_ icon: String, _ label: String, _ n: Int, icon iconColor: Color, value: Color, bg: Color) -> some View {
    VStack(alignment: .leading, spacing: 3.5) {
      HStack(spacing: 7) {
        Ionicon(icon, size: 16, color: iconColor)
        Text(label).font(.system(size: 10.5, weight: .bold)).foregroundStyle(tokens.textSecondary)
      }
      Text("\(n)").font(.system(size: 17.5, weight: .semibold)).foregroundStyle(value).tabularNumbers()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10.5)
    .background(bg, in: .rect(cornerRadius: 10.5))
  }

  private func menu(_ icon: String, _ title: String, _ subtitle: String, _ color: Color, _ route: HomeRoute) -> some View {
    Button {
      Haptics.impact(.light)
      HomeNavigation.shared.path.append(route)
    } label: {
      HStack(spacing: 10.5) {
        Ionicon(icon, size: 20, color: color)
          .frame(width: 35, height: 35)
          .background(color.opacity(tokens.isDark ? 0.1 : 0.08), in: .circle)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(tokens.textPrimary)
          Text(subtitle).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 20, color: tokens.inkSubtle)
      }
      .padding(14)
      .background(tokens.isDark ? Forest.s900 : Forest.s50, in: .rect(cornerRadius: 10.5))
      .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.isDark ? Forest.s800 : Forest.s100, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
  }

  private func load() async {
    loading = true
    defer { loading = false }
    if let data = try? await AdminAPI.send("GET", "/admin/dashboard"), let value = try? JSONDecoder().decode(JSONValue.self, from: data) {
      stats = value
      failed = false
    } else {
      failed = true
    }
  }
}

// MARK: - Kullanıcılar

struct AdminUsersView: View {
  @Environment(\.tokens) private var tokens
  @State private var store = AdminUsersStore()

  var body: some View {
    AdminScreen(title: "Kullanıcılar") {
      VStack(alignment: .leading, spacing: 0) {
        InputField(placeholder: "Ad, soyad, kullanıcı adı veya e-posta ara...", text: $store.search, maxLength: 100)
        if store.total > 0 {
          Text("\(store.total) kullanıcı bulundu").font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary).padding(.top, 5.25)
        }
      }
      .padding(.horizontal, 14)
      .padding(.top, 14)

      if store.failed { ErrorBanner(message: "Kullanıcı listesi alınamadı").padding(14) }

      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(store.users) { user in
            row(user)
              .padding(.horizontal, 14)
              .padding(.top, 10.5)
              .onAppear { if user.id == store.users.last?.id { Task { await store.load(append: true) } } }
          }
          if store.loading || store.loadingMore { ProgressView().tint(tokens.accent).padding(.vertical, 14) }
          if store.users.isEmpty && !store.loading {
            EmptyState(
              icon: "people-outline", title: "Kullanıcı bulunamadı",
              message: store.search.trimmingCharacters(in: .whitespaces).isEmpty ? "Henüz sistemde kayıtlı kullanıcı yok" : "Aramanla eşleşen kullanıcı yok"
            )
            .padding(.top, 42)
          }
        }
        .padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .refreshable { await store.load() }
    }
    // Arama değişince 400 ms bekleyip baştan yükle (ilk açılışta da çalışır).
    .task(id: store.search) {
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      await store.load()
    }
  }

  private func row(_ user: AdminUser) -> some View {
    let dark = tokens.isDark
    let premium = user.isPremium == true
    let orange = dark ? Color(hex: 0xfb923c) : Color(hex: 0xea580c)
    return Button {
      Haptics.impact(.light)
      HomeNavigation.shared.path.append(.adminUser(user.id))
    } label: {
      HStack(spacing: 10.5) {
        avatar(user.avatarUrl, size: 42, tint: premium ? orange : tokens.accent)
          .background(premium ? Color(hex: 0xf97316).opacity(dark ? 0.2 : 0.15) : (dark ? Forest.s800 : Forest.s100), in: .circle)
        VStack(alignment: .leading, spacing: 7) {
          HStack(spacing: 7) {
            Text(user.firstName != nil && user.lastName != nil ? "\(user.firstName!) \(user.lastName!)" : "İsimsiz Kullanıcı")
              .font(.system(size: 14, weight: .bold)).foregroundStyle(tokens.textPrimary).lineLimit(1)
            if premium { Badge("PREMIUM", variant: .warning, size: .sm) }
            if user.isActive != true { Badge("PASİF", variant: .danger, size: .sm) }
          }
          Text("\(user.username.map { "@\($0) · " } ?? "")\(user.email)")
            .font(.system(size: 12.25)).foregroundStyle(tokens.textSecondary).lineLimit(1)
          if let roles = user.roles, !roles.isEmpty {
            FlowLayout(spacing: 3.5) { ForEach(roles, id: \.self) { Badge($0, size: .sm) } }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Ionicon(dirIcon("chevron-forward"), size: 20, color: tokens.inkSubtle)
      }
      .padding(14)
      .background(premium ? (dark ? Color(hex: 0xf97316).opacity(0.1) : Color(hex: 0xfff7ed)) : tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(
        RoundedRectangle(cornerRadius: 21).stroke(premium ? (dark ? Color(hex: 0xf97316).opacity(0.4) : Color(hex: 0xfdba74)) : tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.8))
  }

}

/// Profil fotoğrafı ya da kişi simgesi.
@ViewBuilder
private func avatar(_ url: String?, size: CGFloat, tint: Color) -> some View {
  if let url, let u = URL(string: url) {
    RemoteImage(url: u) { Color.clear }
      .frame(width: size, height: size)
      .clipShape(.circle)
  } else {
    Ionicon("person", size: size * 2 / 3, color: tint).frame(width: size, height: size)
  }
}

// MARK: - Kullanıcı ayrıntısı

struct AdminUserDetailView: View {
  @Environment(\.tokens) private var tokens
  let userId: String
  @State private var user: AdminUser?
  @State private var roles: [AdminRole] = []
  @State private var sessions = 0
  @State private var loading = true
  @State private var busy = false

  private var isCurrentUser: Bool { AuthStore.shared.user?.id == userId }

  var body: some View {
    AdminScreen(title: "Kullanıcı Detayı") {
      if loading && user == nil {
        Spacer()
        ProgressView("Kullanıcı bilgileri yükleniyor...").tint(tokens.accent)
        Spacer()
      } else if let user {
        ScrollView {
          VStack(spacing: 14) {
            profile(user)
            premium(user)
            rolesCard(user)
            sessionsCard
          }
          .padding(14)
          .padding(.bottom, 84)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
      } else {
        Spacer()
        EmptyState(icon: "person-outline", title: "Kullanıcı Bulunamadı", message: "Bu kullanıcıya ait bilgi bulunamadı.") {
          AppButton(title: "Geri Dön") { HomeNavigation.shared.path.removeLast() }.frame(width: 180)
        }
        Spacer()
      }
    }
    .task { await load() }
  }

  private func profile(_ user: AdminUser) -> some View {
    let inactive = user.isActive == false
    return Card {
      HStack {
        avatar(user.avatarUrl, size: 56, tint: tokens.accent)
          .background(tokens.isDark ? Accent.s500.opacity(0.1) : Accent.s50, in: .circle)
        Spacer()
        Badge(inactive ? "PASİF" : "AKTİF", variant: inactive ? .danger : .success)
      }
      .padding(.bottom, 14)
      Text("\(user.firstName ?? "") \(user.lastName ?? "")").font(.system(size: 17.5, weight: .bold)).foregroundStyle(tokens.textPrimary)
      Text(user.email).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).padding(.bottom, 14)
      AppButton(title: inactive ? "Hesabı Aktifleştir" : "Hesabı Pasife Al", variant: inactive ? .primary : .danger, loading: busy) {
        Task { await toggleStatus(user) }
      }
    }
  }

  private func premium(_ user: AdminUser) -> some View {
    let dark = tokens.isDark
    let isPremium = user.isPremium == true
    return VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Premium").font(.system(size: 15.75, weight: .bold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Badge(isPremium ? "PREMIUM" : "FREE", variant: isPremium ? .warning : .neutral)
      }
      .padding(.bottom, 10.5)
      if isPremium, let until = user.premiumUntil, let date = ISO8601DateFormatter.lenient(until) {
        Text("Bitiş: \(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))))")
          .font(.system(size: 12.25)).foregroundStyle(dark ? Forest.s300 : Forest.s600).padding(.bottom, 10.5)
      }
      HStack(spacing: 10.5) {
        AppButton(title: "1 Ay Ver", variant: .outline, loading: busy) { setPremium("monthly") }
        AppButton(title: "1 Yıl Ver", loading: busy) { setPremium("yearly") }
      }
      if isPremium {
        AppButton(title: "Premium'u Kaldır", variant: .danger, loading: busy) { setPremium("none") }.padding(.top, 10.5)
      }
    }
    .padding(17.5)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isPremium ? (dark ? Color(hex: 0xf97316).opacity(0.1) : Color(hex: 0xfff7ed)) : tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(
      RoundedRectangle(cornerRadius: 21).stroke(isPremium ? (dark ? Color(hex: 0xf97316).opacity(0.4) : Color(hex: 0xfdba74)) : tokens.line, lineWidth: 1))
  }

  private func rolesCard(_ user: AdminUser) -> some View {
    let userRoles = user.roles ?? []
    let addable = roles.filter { !userRoles.contains($0.name) }
    return Card {
      Text("Roller").font(.system(size: 15.75, weight: .bold)).foregroundStyle(tokens.textPrimary).padding(.bottom, 10.5)
      if userRoles.isEmpty {
        Text("Hiç rol atanmamış").font(.system(size: 12.25)).foregroundStyle(Forest.s400).padding(.bottom, 14)
      } else {
        FlowLayout(spacing: 7) {
          ForEach(userRoles, id: \.self) { name in
            HStack(spacing: 3.5) {
              Badge(name)
              if let role = roles.first(where: { $0.name == name }) {
                Button { Haptics.impact(.light); Task { await removeRole(role) } } label: {
                  Ionicon("close", size: 12, color: red)
                    .frame(width: 17.5, height: 17.5)
                    .background(tokens.isDark ? red.opacity(0.1) : Color(hex: 0xfef2f2), in: .circle)
                }
                .buttonStyle(PressableStyle())
                .disabled(busy)
                .accessibilityLabel("\(name) rolünü kaldır")
              }
            }
          }
        }
        .padding(.bottom, 14)
      }
      Rectangle().fill(tokens.line).frame(height: 1)
      Text("Rol Ekle").font(.system(size: 12.25, weight: .medium)).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s700).padding(.top, 10.5).padding(.bottom, 7)
      FlowLayout(spacing: 7) {
        ForEach(addable) { role in
          Button { Haptics.impact(.light); Task { await assignRole(role) } } label: {
            HStack(spacing: 3.5) {
              Ionicon("add", size: 16, color: tokens.accent)
              Text(role.name).font(.system(size: 12.25, weight: .medium)).foregroundStyle(tokens.isDark ? Accent.s500 : Accent.s700)
            }
            .padding(.horizontal, 10.5)
            .padding(.vertical, 7)
            .background(tokens.isDark ? Accent.s500.opacity(0.05) : Accent.s50, in: .rect(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.isDark ? Accent.s500.opacity(0.2) : Accent.s200, lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
          .disabled(busy)
        }
      }
      if roles.isEmpty {
        Text("Eklenebilecek rol bulunamadı").font(.system(size: 10.5)).foregroundStyle(Forest.s400)
      }
    }
  }

  private var sessionsCard: some View {
    Card {
      HStack {
        Text("Aktif Oturumlar").font(.system(size: 15.75, weight: .bold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Badge("\(sessions)", variant: sessions > 0 ? .info : .neutral)
      }
      .padding(.bottom, 10.5)
      if sessions == 0 {
        Text("Bu kullanıcının aktif oturumu bulunmuyor").font(.system(size: 12.25)).foregroundStyle(Forest.s400)
      } else {
        Text("Bu kullanıcının \(sessions) aktif oturumu var. Kapatırsan tüm cihazlarda yeniden giriş yapması gerekir.")
          .font(.system(size: 12.25)).foregroundStyle(tokens.isDark ? Forest.s300 : Forest.s600).padding(.bottom, 10.5)
        AppButton(title: "Tüm Oturumları Kapat", variant: .danger, loading: busy) { revokeAll() }
      }
    }
  }

  // MARK: İşlemler

  private func load() async {
    loading = true
    defer { loading = false }
    do {
      async let u = AdminAPI.user(userId)
      async let r = AdminAPI.roles()
      user = try await u
      roles = (try? await r) ?? []
      sessions = await AdminAPI.sessionCount(userId)
    } catch {
      AppAlert.error("Hata", "Kullanıcı bilgileri alınamadı")
    }
  }

  private func toggleStatus(_ user: AdminUser) async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    let activating = user.isActive == false
    do {
      try await AdminAPI.send("POST", "/admin/users/\(userId)/\(activating ? "activate" : "deactivate")")
      await load()
      AppAlert.success("Başarılı", "Kullanıcı \(activating ? "aktif edildi" : "pasife alındı")")
    } catch {
      AppAlert.error("Hata", "Durum değiştirilemedi")
    }
  }

  private func assignRole(_ role: AdminRole) async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    do {
      try await AdminAPI.send("POST", "/admin/users/\(userId)/roles", body: ["roleId": .string(role.id)])
      updateRoles((user?.roles ?? []) + [role.name])
      AppAlert.success("Başarılı", "Rol atandı")
    } catch {
      await load()
      AppAlert.error("Hata", "Rol atanamadı")
    }
  }

  private func removeRole(_ role: AdminRole) async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    do {
      try await AdminAPI.send("DELETE", "/admin/users/\(userId)/roles/\(role.id)")
      updateRoles((user?.roles ?? []).filter { $0 != role.name })
      AppAlert.success("Başarılı", "Rol kaldırıldı")
    } catch {
      await load()
      AppAlert.error("Hata", "Rol kaldırılamadı")
    }
  }

  private func updateRoles(_ list: [String]) {
    user?.roles = list
    if isCurrentUser { AuthStore.shared.setRoles(list) }
  }

  private func setPremium(_ plan: String) {
    let remove = plan == "none"
    let message = remove ? "Bu kullanıcının premium üyeliği kaldırılacak." : "Bu kullanıcıya \(plan == "monthly" ? "1 aylık" : "1 yıllık") premium verilecek."
    AppAlert.confirm("Emin misin?", message, confirmText: remove ? "Kaldır" : "Ver", cancelText: "Vazgeç", destructive: remove) {
      busy = true
      defer { busy = false }
      do {
        try await AdminAPI.send("POST", "/admin/users/\(userId)/premium", body: ["plan": .string(plan)])
        await load()
        AppAlert.success("Başarılı", remove ? "Premium kaldırıldı" : "Premium verildi")
      } catch {
        AppAlert.error("Hata", "Premium durumu değiştirilemedi")
      }
    }
  }

  private func revokeAll() {
    AppAlert.confirm(
      "Emin misin?", "Kullanıcının tüm oturumları kapatılacak; her cihazda yeniden giriş yapması gerekecek.", confirmText: "Kapat",
      cancelText: "Vazgeç", destructive: true
    ) {
      busy = true
      defer { busy = false }
      do {
        try await AdminAPI.send("POST", "/admin/users/\(userId)/sessions/revoke-all")
        sessions = 0
        AppAlert.success("Başarılı", "Tüm oturumlar kapatıldı")
      } catch {
        AppAlert.error("Hata", "Oturumlar kapatılamadı")
      }
    }
  }
}

extension ISO8601DateFormatter {
  /// Kesirli saniyeli ya da saniyesiz ISO tarih.
  static func lenient(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
  }
}

// MARK: - Roller

struct AdminRolesView: View {
  @Environment(\.tokens) private var tokens
  @State private var roles: [AdminRole] = []
  @State private var newRole = ""
  @State private var editing: AdminRole?
  @State private var editName = ""
  @State private var loading = false
  @State private var initialLoading = true

  var body: some View {
    AdminScreen(title: "Roller") {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Card {
            HStack(spacing: 7) {
              Ionicon(editing == nil ? "add-circle-outline" : "create-outline", size: 20, color: tokens.accent)
              Text(editing == nil ? "Yeni Rol Oluştur" : "Rolü Düzenle").font(.system(size: 15.75, weight: .bold)).foregroundStyle(tokens.textPrimary)
            }
            .padding(.bottom, 10.5)
            InputField(placeholder: editing == nil ? "Örn: editor" : "Rol adı", text: editing == nil ? $newRole : $editName)
            HStack(spacing: 7) {
              if editing != nil {
                AppButton(title: "İptal", variant: .outline) {
                  editing = nil
                  editName = ""
                }
              }
              AppButton(title: editing == nil ? "Oluştur" : "Güncelle", loading: loading) {
                Task { if editing == nil { await create() } else { await update() } }
              }
            }
            .padding(.top, 10.5)
          }
          .padding(.bottom, 14)

          Text("Mevcut Roller").font(.system(size: 15.75, weight: .bold)).foregroundStyle(tokens.textPrimary).padding(.leading, 3.5).padding(.bottom, 10.5)

          if initialLoading {
            HStack {
              Spacer()
              ProgressView("Roller yükleniyor...").tint(tokens.accent)
              Spacer()
            }
            .padding(.vertical, 21)
          } else if roles.isEmpty {
            EmptyState(icon: "shield-outline", title: "Henüz rol oluşturulmamış", message: "Yukarıdaki formdan yeni bir rol oluşturabilirsiniz")
              .frame(maxWidth: .infinity)
              .padding(.top, 21)
          } else {
            VStack(spacing: 10.5) {
              ForEach(roles) { role in row(role) }
            }
          }
        }
        .padding(14)
        .padding(.bottom, 84)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .refreshable { await load() }
    }
    .task { await load() }
  }

  private func row(_ role: AdminRole) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 3.5) {
        Badge(role.name)
        Text("ID: \(role.id)").font(.system(size: 10.5)).foregroundStyle(Forest.s400)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 7) {
        Button {
          Haptics.impact(.light)
          editing = role
          editName = role.name
        } label: {
          Ionicon("pencil", size: 18, color: tokens.isDark ? Forest.s300 : Forest.s600)
            .frame(width: 34, height: 34)
            .background(tokens.isDark ? Color.white.opacity(0.1) : Forest.s100, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(role.name) rolünü düzenle")
        Button { Haptics.impact(.light); delete(role) } label: {
          Ionicon("trash-outline", size: 18, color: red)
            .frame(width: 34, height: 34)
            .background(tokens.isDark ? red.opacity(0.1) : Color(hex: 0xfef2f2), in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(role.name) rolünü sil")
      }
    }
    .padding(14)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private static func valid(_ name: String) -> Bool {
    AdminRoleName.valid(name)
  }

  private static func clean(_ name: String) -> String { AdminRoleName.clean(name) }

  private func load() async {
    loading = true
    defer {
      loading = false
      initialLoading = false
    }
    do { roles = try await AdminAPI.roles() } catch { AppAlert.error("Hata", "Roller alınamadı") }
  }

  private func create() async {
    guard !newRole.isEmpty else { return AppAlert.error("Hata", "Rol adı gerekli") }
    guard Self.valid(newRole) else { return AppAlert.error("Hata", "Rol adı sadece harf ve alt çizgi (_) içerebilir.\nÖrnek: test_role") }
    loading = true
    defer { loading = false }
    do {
      try await AdminAPI.send("POST", "/admin/roles", body: ["name": .string(Self.clean(newRole))])
      newRole = ""
      AppAlert.success("Başarılı", "Rol oluşturuldu")
      await load()
    } catch {
      AppAlert.error("Hata", "Rol oluşturulamadı. Bu isimde rol zaten var olabilir.")
    }
  }

  private func update() async {
    guard let editing, !editName.isEmpty else { return }
    guard Self.valid(editName) else { return AppAlert.error("Hata", "Rol adı sadece harf ve alt çizgi (_) içerebilir.\nÖrnek: test_role") }
    loading = true
    defer { loading = false }
    do {
      try await AdminAPI.send("PATCH", "/admin/roles/\(editing.id)", body: ["name": .string(Self.clean(editName))])
      self.editing = nil
      editName = ""
      AppAlert.success("Başarılı", "Rol güncellendi")
      await load()
    } catch {
      AppAlert.error("Hata", "Rol güncellenemedi")
    }
  }

  private func delete(_ role: AdminRole) {
    AppAlert.confirm("Rolü Sil", "Bu rolü silmek istediğinize emin misiniz?", confirmText: "Sil", cancelText: "Vazgeç", destructive: true) {
      loading = true
      defer { loading = false }
      do {
        try await AdminAPI.send("DELETE", "/admin/roles/\(role.id)")
        AppAlert.success("Başarılı", "Rol silindi")
        await load()
      } catch {
        AppAlert.error("Hata", "Rol silinemedi")
      }
    }
  }
}
