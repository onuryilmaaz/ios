import SwiftUI

/// Ana sayfa yığınının ekranları. RN: navigation/types.ts `HomeStackParamList`.
enum HomeRoute: Hashable {
  case layout
  case qibla
  case location
  case dua
  case calendar
  case history
  case esma
  case alarms
  case hutbe
  case profile
  case settings
  case changePassword
  case changeEmail
  case account
  case ozelGun
  case admin
  case adminUsers
  case adminUser(String)
  case adminRoles

  @ViewBuilder
  var destination: some View {
    switch self {
    case .layout: HomeLayoutView()
    case .dua: DuaView()
    case .esma: EsmaulHusnaView()
    case .hutbe: HutbeView()
    case .alarms: AlarmsView()
    case .profile: ProfileView()
    case .settings: SettingsView()
    case .changePassword: ChangePasswordView()
    case .changeEmail: ChangeEmailView()
    case .account: AccountView()
    case .location: LocationSelectionView()
    case .qibla: QiblaFinderView()
    case .calendar: HijriCalendarView()
    case .ozelGun: OzelGunView()
    case .history: PrayerHistoryView()
    case .admin: AdminDashboardView()
    case .adminUsers: AdminUsersView()
    case .adminUser(let id): AdminUserDetailView(userId: id)
    case .adminRoles: AdminRolesView()
    }
  }
}
