import SwiftUI

/// İl → ilçe seçimi. RN: screens/user/LocationSelectionScreen.tsx
struct LocationSelectionView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var stateId: String? = Locations.selectedStateId
  @State private var districtId: String? = LocalStore.string(Locations.districtIdKey)
  @State private var step: Step = Locations.selectedStateId == nil ? .state : .district

  private enum Step { case state, district }

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
                Text(step == .district ? (selectedState?.name ?? "") : t("location.chooseState"))
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
            }
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10.5)
          .background(tokens.surface, in: .rect(cornerRadius: 21))
          .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
          .padding(.vertical, 8)

          if step == .state {
            ForEach(Locations.states, id: \._id) { state in
              let selected = stateId == state._id
              item(state.name, selected: selected, showChevron: true) {
                stateId = state._id
                districtId = nil
                step = .district
              }
            }
          } else if let stateId {
            let districts = Locations.districts(ofState: stateId)
            if districts.isEmpty {
              VStack(spacing: 14) {
                Ionicon("alert-circle-outline", size: 48, color: dark ? Color(hex: 0x4b5563) : Forest.s400)
                Text(t("location.noDistricts")).foregroundStyle(dark ? Forest.s300 : Forest.s500).multilineTextAlignment(.center)
              }
              .frame(maxWidth: .infinity)
              .padding(28)
              .background(dark ? Forest.s900.opacity(0.7) : .white, in: .rect(cornerRadius: 10.5))
              .overlay(RoundedRectangle(cornerRadius: 10.5).stroke(tokens.line, lineWidth: 1))
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
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func back() {
    if step == .district {
      step = .state
      districtId = nil
    } else {
      dismiss()
    }
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
