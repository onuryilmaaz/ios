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
  case adminGroupReports
  case imsakiye
  case hatimPlan
  case fastJournal
  case zakat
  case hatimGroups
  case hatimGroup(String)
  case kaza
  case dhikr
  case circles
  case circle(String)
  case yearSummary
  #if PRAYER_LOCK
  case prayerLock
  #endif

  /// Panelden kapatılabilen ekranın modülü.
  private var module: String? {
    switch self {
    case .qibla: "qibla"
    case .dua: "dua"
    case .esma: "esma"
    case .calendar: "calendar"
    case .hutbe: "hutbe"
    case .alarms: "alarms"
    case .imsakiye, .fastJournal: "ramadan"
    case .zakat: "zakat"
    case .hatimPlan: "hatim_plan"
    case .hatimGroups, .hatimGroup: "hatim_groups"
    case .kaza: "kaza"
    case .dhikr: "dhikr"
    case .circles, .circle: "streak_circles"
    default: nil
    }
  }

  @ViewBuilder
  var destination: some View {
    if let module, !AppControlStore.shared.isOn(module) || (self == .kaza && !AppControlStore.shared.supports("kaza"))
      || (module == "streak_circles" && !AppControlStore.shared.supports("streakCircles"))
      || (self == .yearSummary && !YearSummaryStore.available) {
      ModuleClosedView()
    } else {
      screen
    }
  }

  @ViewBuilder
  private var screen: some View {
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
    case .adminGroupReports: AdminGroupReportsView()
    case .imsakiye: ImsakiyeView()
    case .hatimPlan: HatimPlanView()
    case .fastJournal: FastJournalView()
    case .zakat: ZakatView()
    case .hatimGroups: HatimGroupsView()
    case .hatimGroup(let id): HatimGroupView(id: id)
    case .kaza: KazaView()
    case .dhikr: DhikrView()
    case .circles: StreakCirclesView()
    case .circle(let id): StreakCircleView(id: id)
    case .yearSummary: YearSummaryView()
    #if PRAYER_LOCK
    case .prayerLock: PrayerLockView()
    #endif
    }
  }
}
