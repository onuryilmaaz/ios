import PhotosUI
import SwiftUI

/// Profil. RN: screens/user/ProfileScreen.tsx
struct ProfileView: View {
  @Environment(\.tokens) private var tokens
  @State private var editing = false
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var username = ""
  @State private var phone = ""
  @State private var gender: String?
  @State private var saving = false
  @State private var uploading = false
  @State private var photoItem: PhotosPickerItem?
  @State private var localAvatar: UIImage?

  var body: some View {
    let user = AuthStore.shared.user
    VStack(spacing: 0) {
      StandardHeader(title: t("profile.title"))
      ScrollView {
        VStack(spacing: 0) {
          header(user)
            .padding(.bottom, 21)

          BadgeShowcase().padding(.horizontal, 14).padding(.bottom, 14)

          personalInfo(user).padding(.horizontal, 14).padding(.bottom, 14)

          if user?.roles?.contains("admin") == true {
            adminCard.padding(.horizontal, 14).padding(.bottom, 14)
          }

          themeRow.padding(.horizontal, 14).padding(.bottom, 14)

          settingsMenu.padding(.horizontal, 14).padding(.bottom, 56)
        }
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .refreshable { await load() }
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
    .overlay { if uploading { UploadOverlay(message: t("profile.uploading")) } }
    .task { await load() }
    .onChange(of: photoItem) { _, item in
      guard let item else { return }
      Task { await upload(item) }
    }
  }

  // MARK: - Sections

  private func header(_ user: AuthUser?) -> some View {
    let dark = tokens.isDark
    return VStack(spacing: 0) {
      ZStack(alignment: .bottomTrailing) {
        Group {
          if let localAvatar {
            Image(uiImage: localAvatar).resizable().scaledToFill()
          } else if let raw = user?.avatarUrl, let url = URL(string: raw) {
            RemoteImage(url: url) { avatarPlaceholder }
          } else {
            avatarPlaceholder
          }
        }
        .frame(width: 98, height: 98)
        .background(dark ? Accent.s500.opacity(0.1) : Accent.s50)
        .clipShape(.circle)
        .overlay(Circle().stroke(dark ? Forest.s800 : Forest.s100, lineWidth: 4))

        PhotosPicker(selection: $photoItem, matching: .images) {
          Ionicon("camera", size: 18, color: .white)
            .frame(width: 35, height: 35)
            .background(dark ? Accent.s500 : Accent.s600, in: .circle)
            .overlay(Circle().stroke(dark ? Forest.s800 : Forest.s100, lineWidth: 2))
        }
        .disabled(uploading)
        .accessibilityLabel(t("profile.changePhoto"))
      }
      .padding(.top, 28)

      Text("\(user?.firstName ?? "") \(user?.lastName ?? "")")
        .font(.system(size: 21, weight: .bold))
        .foregroundStyle(dark ? .white : Forest.s900)
        .padding(.top, 14)
      if let name = user?.username, !name.isEmpty {
        Text(verbatim: "@\(name)")
          .font(.system(size: 15.75, weight: .medium))
          .foregroundStyle(dark ? Accent.s400 : Accent.s600)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var avatarPlaceholder: some View {
    Ionicon("person", size: 44, color: tokens.isDark ? Accent.s400 : Accent.s600)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func personalInfo(_ user: AuthUser?) -> some View {
    Card {
      HStack {
        Text(t("profile.personalInfo"))
          .font(.system(size: 15.75, weight: .bold))
          .foregroundStyle(tokens.isDark ? .white : Forest.s900)
        Spacer()
        if !editing {
          Button {
            editing = true
          } label: {
            Ionicon("pencil", size: 20, color: tokens.isDark ? Accent.s400 : Accent.s600)
          }
          .buttonStyle(PressableStyle())
          .accessibilityLabel(t("profile.editInfo"))
        }
      }
      .padding(.bottom, 14)

      if editing {
        InputField(label: t("profile.firstName"), placeholder: t("profile.firstNamePlaceholder"), text: $firstName, contentType: .givenName)
        InputField(label: t("profile.lastName"), placeholder: t("profile.lastNamePlaceholder"), text: $lastName, contentType: .familyName)
        InputField(label: t("profile.username"), placeholder: t("profile.usernamePlaceholder"), text: $username, keyboard: .asciiCapable, contentType: .username)
        InputField(label: t("profile.phone"), placeholder: "+90 555 123 45 67", text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)
        genderPicker.padding(.bottom, 14)
        HStack(spacing: 10.5) {
          AppButton(title: t("common.cancel"), variant: .outline) {
            editing = false
            fillForm(AuthStore.shared.user)
          }
          AppButton(title: t("common.save"), loading: saving) { Task { await save() } }
        }
        .padding(.top, 7)
      } else {
        VStack(spacing: 10.5) {
          infoRow("person-outline", t("profile.fullName"), "\(user?.firstName ?? "-") \(user?.lastName ?? "")")
          infoRow("at-circle-outline", t("profile.username"), user?.username.flatMap { $0.isEmpty ? nil : "@\($0)" } ?? "-")
          infoRow("call-outline", t("profile.phone"), user?.phone.flatMap { $0.isEmpty ? nil : $0 } ?? "-")
          infoRow("mail-outline", t("profile.email"), user?.email ?? "-")
          infoRow("person-outline", t("profile.gender"), user?.gender == "erkek" ? t("profile.male") : user?.gender == "kadin" ? t("profile.female") : "-")
        }
      }
    }
  }

  private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
    HStack(spacing: 10.5) {
      Ionicon(icon, size: 20, color: tokens.isDark ? Color(hex: 0x4b5563) : Forest.s500)
      VStack(alignment: .leading, spacing: 0) {
        Text(label).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
        Text(value).font(.system(size: 12.25, weight: .medium)).foregroundStyle(tokens.isDark ? .white : Forest.s900)
      }
      Spacer(minLength: 0)
    }
    .padding(10.5)
    .background(tokens.isDark ? Forest.s900 : Forest.s50, in: .rect(cornerRadius: 10.5))
    .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.isDark ? Forest.s800 : .clear, lineWidth: 1))
  }

  private var genderPicker: some View {
    let dark = tokens.isDark
    let active = dark ? Accent.s400 : Accent.s600
    let inactive = dark ? Forest.s600 : Forest.s400
    return VStack(alignment: .leading, spacing: 7) {
      Text(t("profile.gender"))
        .font(.system(size: 12.25, weight: .medium))
        .foregroundStyle(dark ? Forest.s300 : Forest.s700)
      HStack(spacing: 10.5) {
        ForEach([("erkek", t("profile.male")), ("kadin", t("profile.female"))], id: \.0) { value, label in
          let selected = gender == value
          Button {
            Haptics.impact(.light)
            gender = selected ? nil : value
          } label: {
            VStack(spacing: 5.25) {
              Text(label).font(.system(size: 12.25, weight: .bold)).foregroundStyle(selected ? active : inactive)
              if selected { Ionicon("checkmark-circle", size: 14, color: active) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
              selected ? (dark ? Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255).opacity(0.14) : Color(red: 15 / 255, green: 118 / 255, blue: 110 / 255).opacity(0.07))
                : (dark ? Forest.s900 : Forest.s100),
              in: .rect(cornerRadius: 14)
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? active : .clear, lineWidth: 1.5))
          }
          .buttonStyle(PressableStyle(pressedOpacity: 0.75))
        }
      }
      if gender == "kadin" {
        Text(t("profile.ozelGunHint")).font(.system(size: 12)).foregroundStyle(Gold.s400)
      }
    }
  }

  private var adminCard: some View {
    Card {
      HStack(spacing: 10.5) {
        Ionicon("shield-checkmark-outline", size: 20, color: tokens.isDark ? Accent.s400 : Accent.s600)
          .frame(width: 35, height: 35)
          .background(tokens.isDark ? Accent.s400.opacity(0.2) : Accent.s50, in: .circle)
        VStack(alignment: .leading, spacing: 0) {
          Text(t("profile.adminPanel")).font(.system(size: 14, weight: .bold)).foregroundStyle(tokens.isDark ? .white : Forest.s900)
          Text(t("profile.adminSub")).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          Haptics.impact(.light)
          HomeNavigation.shared.path.append(.admin)
        } label: {
          Text(t("profile.open"))
            .font(.system(size: 12.25, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tokens.isDark ? Accent.s400 : Accent.s700, in: .capsule)
        }
        .buttonStyle(PressableStyle(pressedOpacity: 0.8))
      }
    }
  }

  private var themeRow: some View {
    let dark = tokens.isDark
    return Button {
      Haptics.impact(.medium)
      ThemeStore.shared.toggle()
    } label: {
      HStack(spacing: 0) {
        Ionicon(dark ? "moon" : "sunny", size: 20, color: dark ? Gold.s300 : Gold.s500)
          .frame(width: 38.5, height: 38.5)
          .background(dark ? Color(hex: 0x3d3418) : Gold.s50, in: .circle)
          .padding(.trailing, 10.5)
        VStack(alignment: .leading, spacing: 1.75) {
          Text(t("profile.theme")).font(.system(size: 15, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
          Text(t(dark ? "profile.themeDark" : "profile.themeLight")).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
        }
        Spacer()
        HStack(spacing: 1.75) {
          Ionicon("sunny", size: 16, color: dark ? .white.opacity(0.3) : Amber.s600)
            .frame(width: 28, height: 28)
            .background(dark ? .clear : .white, in: .circle)
          Ionicon("moon", size: 16, color: dark ? .white : .black.opacity(0.25))
            .frame(width: 28, height: 28)
            .background(dark ? Color(hex: 0x14b8a6) : .clear, in: .circle)
        }
        .padding(3.5)
        .background(dark ? Color(hex: 0x14b8a6).opacity(0.2) : Forest.s100, in: .capsule)
        .overlay(Capsule().stroke(dark ? Accent.s800 : Forest.s200, lineWidth: 1))
      }
      .padding(14)
      .background(tokens.surface, in: .rect(cornerRadius: 21))
      .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle(pressedOpacity: 0.85))
  }

  private var settingsMenu: some View {
    let items: [(icon: String, key: String, route: HomeRoute)] = [
      ("settings-outline", "appSettings", .settings),
      ("lock-closed-outline", "changePassword", .changePassword),
      ("mail-outline", "changeEmail", .changeEmail),
      ("person-circle-outline", "account", .account),
    ]
    let dark = tokens.isDark
    return Card {
      Text(t("profile.settings"))
        .font(.system(size: 15.75, weight: .bold))
        .foregroundStyle(dark ? .white : Forest.s900)
        .padding(.bottom, 14)
      VStack(spacing: 7) {
        ForEach(items, id: \.key) { item in
          Button {
            HomeNavigation.shared.path.append(item.route)
          } label: {
            HStack(spacing: 10.5) {
              Ionicon(item.icon, size: 20, color: dark ? Color(hex: 0x4b5563) : Forest.s500)
                .frame(width: 35, height: 35)
                .background(dark ? Forest.s800 : .white, in: .circle)
              VStack(alignment: .leading, spacing: 0) {
                Text(t("profile.menu.\(item.key)")).font(.system(size: 14, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
                Text(t("profile.menu.\(item.key)Sub")).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              Ionicon(dirIcon("chevron-forward"), size: 20, color: dark ? Color(hex: 0x4b5563) : Forest.s400)
            }
            .padding(14)
            .background(dark ? Forest.s900 : Forest.s50, in: .rect(cornerRadius: 10.5))
            .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(dark ? Forest.s800 : .clear, lineWidth: 1))
          }
          .buttonStyle(PressableStyle())
        }
      }
    }
  }

  // MARK: - Actions

  private func fillForm(_ user: AuthUser?) {
    firstName = user?.firstName ?? ""
    lastName = user?.lastName ?? ""
    username = user?.username ?? ""
    phone = user?.phone ?? ""
    gender = user?.gender
  }

  private func load() async {
    fillForm(AuthStore.shared.user)
    await AuthStore.shared.refreshUser()
    if !editing { fillForm(AuthStore.shared.user) }
  }

  private func save() async {
    saving = true
    defer { saving = false }
    do {
      let trimmed = phone.trimmingCharacters(in: .whitespaces)
      try await UserAPI.updateProfile(firstName: firstName, lastName: lastName, username: username, phone: trimmed.isEmpty ? nil : trimmed, gender: gender)
      await AuthStore.shared.refreshUser()
      editing = false
      AppAlert.success(t("common.success"), t("profile.updated"))
    } catch {
      AppAlert.error(t("common.error"), t("profile.updateFailed"))
    }
  }

  private func upload(_ item: PhotosPickerItem) async {
    defer { photoItem = nil }
    guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
      AppAlert.error(t("common.error"), t("profile.imagePickFailed"))
      return
    }
    // RN: kare kırpma + 0.8 kalite. Kenar 1024'e sığdırılır.
    let square = image.squareCropped(maxSide: 1024)
    guard let jpeg = square.jpegData(compressionQuality: 0.8) else { return }
    localAvatar = square
    uploading = true
    defer { uploading = false }
    do {
      try await UserAPI.uploadAvatar(jpeg: jpeg)
      await AuthStore.shared.refreshUser()
      localAvatar = nil
      AppAlert.success(t("common.success"), t("profile.avatarUploaded"))
    } catch {
      localAvatar = nil
      AppAlert.error(t("common.error"), t("profile.avatarUploadFailed"))
    }
  }
}

extension UIImage {
  /// Ortadan kare kırpar ve kenarı `maxSide`'a küçültür.
  func squareCropped(maxSide: CGFloat) -> UIImage {
    let side = min(size.width, size.height)
    let target = min(side, maxSide)
    let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target))
    return renderer.image { _ in
      let scale = target / side
      draw(in: CGRect(x: -origin.x * scale, y: -origin.y * scale, width: size.width * scale, height: size.height * scale))
    }
  }
}

/// Kazanılan rozetler ve sıradaki seri rozetine ilerleme. RN: components/gamification/BadgeShowcase.tsx
struct BadgeShowcase: View {
  @Environment(\.tokens) private var tokens

  private static let streakTiers: [(value: Int, id: String)] = [
    (3, "seri_3_gun"), (7, "seri_7_gun"), (14, "seri_14_gun"), (30, "seri_30_gun"), (100, "seri_100_gun"),
  ]

  var body: some View {
    let store = GamificationStore.shared
    let all = Self.objects(store.allBadges)
    let earned: [(id: String, name: String, icon: String)] = {
      guard case .array(let rows)? = store.badges else { return [] }
      return rows.compactMap { row in
        guard let id = row["badge_id"]?.stringValue else { return nil }
        let detail = row["details"] ?? all[id]
        guard let detail else { return nil }
        return (id, Self.badgeName(id, detail["name"]?.stringValue ?? id), detail["icon"]?.stringValue ?? "ribbon")
      }
    }()
    let earnedIds = Set(earned.map(\.id))
    let streak = store.stats?.current_streak ?? 0
    let next = Self.streakTiers.first { !earnedIds.contains($0.id) && streak < $0.value }
    let dark = tokens.isDark

    Card {
      HStack(spacing: 7) {
        Ionicon("ribbon", size: 18, color: tokens.gold)
        Text(t("badges.title")).font(.system(size: 15.75, weight: .bold)).foregroundStyle(dark ? .white : Forest.s900)
        Text(verbatim: "\(earned.count)/\(all.count)")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(dark ? Gold.s300 : Gold.s700)
          .padding(.horizontal, 7)
          .padding(.vertical, 1.75)
          .background(dark ? Color(hex: 0x3d3418) : Gold.s50, in: .capsule)
      }

      if earned.isEmpty {
        HStack(spacing: 10.5) {
          Ionicon("lock-closed", size: 18, color: dark ? Forest.s500 : Forest.s400)
          Text(t("badges.empty")).font(.system(size: 10.5)).foregroundStyle(tokens.textSecondary)
          Spacer(minLength: 0)
        }
        .padding(10.5)
        .background(dark ? Forest.s800 : Forest.s50, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Forest.s700 : Forest.s200, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .padding(.top, 14)
      } else {
        ScrollView(.horizontal) {
          HStack(alignment: .top, spacing: 14) {
            ForEach(earned, id: \.id) { badge in
              VStack(spacing: 3.5) {
                Ionicon(badge.icon, size: 26, color: tokens.gold)
                  .frame(width: 49, height: 49)
                  .background(dark ? Color(hex: 0x3d3418) : Gold.s50, in: .rect(cornerRadius: 14))
                Text(badge.name)
                  .font(.system(size: 12, weight: .bold))
                  .foregroundStyle(tokens.textSecondary)
                  .multilineTextAlignment(.center)
                  .lineLimit(2)
              }
              .frame(width: 56)
            }
          }
          .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 14)
      }

      if let next, let detail = all[next.id] {
        VStack(spacing: 7) {
          HStack(spacing: 8.75) {
            Ionicon(detail["icon"]?.stringValue ?? "ribbon", size: 18, color: tokens.gold)
              .frame(width: 31.5, height: 31.5)
              .background(dark ? Color(hex: 0x3d3418) : Gold.s50, in: .rect(cornerRadius: 10.5))
            VStack(alignment: .leading, spacing: 0) {
              Text(t("badges.next")).font(.system(size: 12, weight: .medium)).foregroundStyle(Forest.s400)
              Text(Self.badgeName(next.id, detail["name"]?.stringValue ?? next.id))
                .font(.system(size: 12.25, weight: .bold))
                .foregroundStyle(dark ? .white : Forest.s900)
            }
            Spacer()
            Text(verbatim: "\(streak)/\(next.value)")
              .font(.system(size: 10.5, weight: .semibold))
              .foregroundStyle(tokens.textSecondary)
          }
          ProgressBar(fraction: Double(streak) / Double(next.value), height: 5.25, fill: Gold.s400)
        }
        .padding(12.25)
        .background(dark ? Forest.s800 : Forest.s50, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(dark ? Forest.s800 : Forest.s100, lineWidth: 1))
        .padding(.top, 14)
      }
    }
    .task { if store.badges == nil { await store.fetchStats() } }
  }

  /// Rozet adı seçili dilde (backend Türkçe döndürür; id ile eşlenir).
  private static func badgeName(_ id: String, _ fallback: String) -> String {
    let key = "badges.names.\(id)"
    let s = t(key)
    return s == key ? fallback : s
  }

  private static func objects(_ value: JSONValue?) -> [String: JSONValue] {
    if case .object(let o)? = value { return o }
    return [:]
  }
}
