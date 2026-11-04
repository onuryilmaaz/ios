import SwiftUI

/// Ülke → il/eyalet → ilçe/şehir seçimi. RN: screens/user/LocationSelectionScreen.tsx
/// Türkiye dışı ülkeler Diyanet'in yurtdışı listesinden; tek eyaletli ülkede eyalet adımı atlanır.
struct LocationSelectionView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var countryId: String = Locations.selectedCountryId
  @State private var stateId: String? = Locations.selectedStateId
  @State private var districtId: String? = LocalStore.string(Locations.districtIdKey)
  @State private var step: Step = Locations.selectedStateId == nil ? .state : .district
  @State private var query = ""

  private enum Step { case country, state, district }

  var body: some View {
    let dark = tokens.isDark
    let teal = dark ? Accent.s500 : Accent.s600
    let selectedState = stateId.flatMap { Locations.state($0) }
    let selectedDistrict = districtId.flatMap(Locations.district)

    VStack(spacing: 0) {
      StandardHeader(title: t("location.title"))
      ScrollView {
        LazyVStack(spacing: 7) {
          HStack {
            Button(action: back) {
              HStack(spacing: 3.5) {
                Ionicon(dirIcon("chevron-back"), size: 24, color: teal)
                Text(headerTitle(selectedState))
                  .font(.system(size: 14, weight: .bold))
                  .foregroundStyle(dark ? .white : Forest.s900)
              }
            }
            .buttonStyle(PressableStyle())
            Spacer()
            if step == .district, let selectedDistrict {
              Text(selectedDistrict.name)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(dark ? Accent.s400 : Accent.s700)
                .padding(.horizontal, 10.5)
                .padding(.vertical, 3.5)
                .background(dark ? Accent.s500.opacity(0.15) : Accent.s50, in: .capsule)
            } else if step == .state {
              // Ülke değiştir: Türkiye dışı vakitler de buradan seçilir.
              Button {
                Haptics.impact(.light)
                query = ""
                step = .country
              } label: {
                HStack(spacing: 3.5) {
                  Ionicon("globe-outline", size: 14, color: dark ? Accent.s400 : Accent.s700)
                  Text(Locations.country(countryId)?.displayName ?? "")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(dark ? Accent.s400 : Accent.s700)
                }
                .padding(.horizontal, 10.5)
                .padding(.vertical, 3.5)
                .background(dark ? Accent.s500.opacity(0.15) : Accent.s50, in: .capsule)
              }
              .buttonStyle(PressableStyle())
              .accessibilityLabel(t("location.changeCountry"))
            }
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10.5)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
          .padding(.vertical, 8)

          switch step {
          case .country:
            searchField
            let list = Locations.countries.filter(matches)
            if list.isEmpty { empty(t("location.noResults")) }
            ForEach(list, id: \.id) { country in
              item(country.displayName, selected: countryId == country.id, showChevron: true) {
                choose(country: country.id)
              }
            }
          case .state:
            ForEach(Locations.states(ofCountry: countryId), id: \._id) { state in
              item(state.name, selected: stateId == state._id, showChevron: true) {
                stateId = state._id
                districtId = nil
                step = .district
              }
            }
          case .district:
            if let stateId {
              let districts = Locations.districts(ofState: stateId)
              if districts.isEmpty {
                empty(t("location.noDistricts"))
              } else {
                ForEach(districts, id: \._id) { district in
                  item(district.name, selected: districtId == district._id, showChevron: false) {
                    districtId = district._id
                    // 'manual': kullanıcı bilerek seçti; konum takibi bunu sessizce değiştirmez.
                    Locations.select(stateId: stateId, districtId: district._id, source: "manual")
                    dismiss()
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func headerTitle(_ selectedState: Locations.State?) -> String {
    switch step {
    case .country: t("location.chooseCountry")
    case .state: countryId == Locations.turkeyId ? t("location.chooseState") : t("location.chooseRegion")
    case .district: selectedState?.name ?? ""
    }
  }

  private var searchField: some View {
    HStack(spacing: 7) {
      Ionicon("search", size: 16, color: tokens.textSecondary)
      TextField(t("location.searchCountry"), text: $query)
        .font(.system(size: 15))
        .foregroundStyle(tokens.textPrimary)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .submitLabel(.search)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(tokens.surface, in: .rect(cornerRadius: 10.5))
    .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.line, lineWidth: 1))
  }

  private func matches(_ c: Locations.Country) -> Bool {
    let q = Locations.foldKey(query)
    return q.isEmpty || Locations.foldKey(c.displayName).contains(q) || Locations.foldKey(c.name).contains(q)
  }

  /// Ülke seçildi: tek eyaleti varsa doğrudan şehirlere geçilir.
  private func choose(country id: String) {
    let states = Locations.states(ofCountry: id)
    if id != countryId {
      stateId = nil
      districtId = nil
    }
    countryId = id
    query = ""
    if states.count == 1, let only = states.first {
      stateId = only._id
      step = .district
    } else {
      step = .state
    }
  }

  private func back() {
    switch step {
    case .district:
      districtId = nil
      // Tek eyaletli ülkede eyalet listesi yok: doğrudan ülkelere dön.
      step = Locations.states(ofCountry: countryId).count == 1 ? .country : .state
    case .state:
      step = .country
    case .country:
      dismiss()
    }
  }

  private func empty(_ text: String) -> some View {
    let dark = tokens.isDark
    return VStack(spacing: 14) {
      Ionicon("alert-circle-outline", size: 48, color: dark ? Color(hex: 0x4b5563) : Forest.s400)
      Text(text).foregroundStyle(dark ? Forest.s300 : Forest.s500).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(28)
    .background(dark ? Forest.s900.opacity(0.7) : .white, in: .rect(cornerRadius: 10.5))
    .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.line, lineWidth: 1))
  }

  private func item(_ name: String, selected: Bool, showChevron: Bool, action: @escaping () -> Void) -> some View {
    let dark = tokens.isDark
    let teal = dark ? Accent.s500 : Accent.s600
    return Button {
      Haptics.impact(.light)
      action()
    } label: {
      HStack {
        Text(name)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(selected ? (dark ? Accent.s400 : Accent.s700) : (dark ? .white : Forest.s900))
          .frame(maxWidth: .infinity, alignment: .leading)
        if selected {
          Ionicon("checkmark-circle", size: 24, color: teal)
        } else if showChevron {
          Ionicon(dirIcon("chevron-forward"), size: 24, color: dark ? Color(hex: 0x4b5563) : Forest.s400)
        }
      }
      .padding(14)
      .background(selected ? (dark ? Accent.s500.opacity(0.1) : Accent.s50) : tokens.surface, in: .rect(cornerRadius: 10.5))
      .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(selected ? (dark ? Accent.s500 : Accent.s600) : tokens.line, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
  }
}
