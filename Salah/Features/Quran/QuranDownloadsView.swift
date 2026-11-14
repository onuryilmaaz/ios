import SwiftUI

enum QuranReciters {
  static let all: [(id: String, name: String)] = [("ar.alafasy", "Alafasy"), ("ar.abdullahbasfar", "Basfar")]
  static func name(_ id: String) -> String { all.first { $0.id == id }?.name ?? id }
}

/// Sure ekranındaki ses indirme düğmesi: indir, ilerleme (dokununca durur), indirildi (dokununca silme onayı).
struct QuranDownloadButton: View {
  @Environment(\.tokens) private var tokens
  let surah: Int
  let surahName: String
  let reciter: String

  var body: some View {
    let downloads = QuranDownloads.shared
    let status = downloads.status(surah: surah, reciter: reciter)
    Button {
      switch status {
      case .none:
        Haptics.impact(.medium)
        downloads.download(surah: surah, reciter: reciter)
      case .downloading:
        Haptics.impact(.light)
        downloads.cancel(surah: surah, reciter: reciter)
      case .done:
        Haptics.impact(.light)
        AppAlert.confirm(
          t("quranOffline.deleteTitle"),
          t("quranOffline.deleteMessage", ["surah": surahName, "reciter": QuranReciters.name(reciter)]),
          confirmText: t("quranOffline.delete"), destructive: true
        ) { downloads.delete(surah: surah, reciter: reciter) }
      }
    } label: {
      HStack(spacing: 5.25) {
        switch status {
        case .none:
          Ionicon("cloud-download-outline", size: 14, color: tokens.inkMuted)
          Text(t("quranOffline.download")).foregroundStyle(tokens.textSecondary)
        case .downloading(let p):
          ProgressRing(value: p).frame(width: 13, height: 13)
          Text(t("quranOffline.downloading", ["percent": Int(p * 100)])).foregroundStyle(tokens.accent).tabularNumbers()
        case .done:
          Ionicon("checkmark-circle", size: 14, color: tokens.accent)
          Text(t("quranOffline.downloaded")).foregroundStyle(tokens.accent)
        }
      }
      .font(.system(size: 12, weight: .bold))
      .padding(.horizontal, 8.75).padding(.vertical, 3.5)
      .background(status == .none ? tokens.fill : tokens.accentSoft, in: .capsule)
      .overlay(Capsule().stroke(status == .none ? tokens.line : tokens.accent, lineWidth: 1))
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(status == .none ? t("quranOffline.downloadA11y") : status == .done ? t("quranOffline.deleteTitle") : t("quranOffline.cancel"))
  }
}

private struct ProgressRing: View {
  @Environment(\.tokens) private var tokens
  let value: Double
  var body: some View {
    ZStack {
      Circle().stroke(tokens.line, lineWidth: 2)
      Circle().trim(from: 0, to: max(0.02, value)).stroke(tokens.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
    }
  }
}

/// Kur'an sekmesindeki "İndirilenler": metinlerin tamamını indirme, inen sesler ve silme.
struct QuranDownloadsView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  @State private var surahs: [Surah] = []

  var body: some View {
    let downloads = QuranDownloads.shared
    VStack(spacing: 0) {
      HStack {
        Text(t("quranOffline.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        Button { Haptics.impact(.light); dismiss() } label: {
          Ionicon("close", size: 20, color: tokens.inkMuted).frame(width: 35, height: 35).background(tokens.surface, in: .circle)
            .overlay(Circle().stroke(tokens.line, lineWidth: 1))
        }.buttonStyle(PressableStyle()).accessibilityLabel(t("common.close"))
      }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          textCard(downloads)
          mushafCard(downloads)
          audioCard(downloads)
        }.padding(16).padding(.bottom, 24)
      }.scrollIndicators(.hidden)
    }
    .background(tokens.canvas)
    .task {
      surahs = await QuranService.surahs()
      downloads.refreshSize()
      downloads.refreshMushaf()
    }
  }

  private func textCard(_ downloads: QuranDownloads) -> some View {
    VStack(alignment: .leading, spacing: 10.5) {
      Text(t("quranOffline.textTitle")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
      Text(t("quranOffline.textHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      let count = downloads.cachedTextCount
      if let p = downloads.textProgress {
        ProgressBarLine(value: p)
        HStack {
          Text(t("quranOffline.downloading", ["percent": Int(p * 100)])).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.accent).tabularNumbers()
          Spacer()
          Button { Haptics.impact(.light); downloads.cancelText() } label: {
            Text(t("quranOffline.cancel")).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.textSecondary)
          }.buttonStyle(PressableStyle())
        }
      } else {
        Text(t("quranOffline.textCount", ["count": count])).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        if count < 114 {
          AppButton(title: t("quranOffline.textDownload"), variant: .secondary) {
            Haptics.impact(.medium)
            downloads.downloadAllText()
          }
        }
      }
    }
    .padding(17.5).frame(maxWidth: .infinity, alignment: .leading)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private func mushafCard(_ downloads: QuranDownloads) -> some View {
    let script = QuranReadingStore.shared.mushafScript
    return VStack(alignment: .leading, spacing: 10.5) {
      HStack {
        Text(t("quranOffline.mushafTitle")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        if downloads.mushafBytes > 0 {
          Text(t("quranOffline.size", ["size": downloads.mushafBytes.formatted(.byteCount(style: .file).locale(Localizer.shared.locale))]))
            .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        }
      }
      Text(t(script == .text ? "quranOffline.mushafHintText" : "quranOffline.mushafHintScript", ["script": t(script.labelKey)]))
        .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
      if let p = downloads.mushafProgress {
        ProgressBarLine(value: p)
        HStack {
          Text(t("quranOffline.downloading", ["percent": Int(p * 100)])).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.accent).tabularNumbers()
          Spacer()
          Button { Haptics.impact(.light); downloads.cancelMushaf() } label: {
            Text(t("quranOffline.cancel")).font(.system(size: 13, weight: .semibold)).foregroundStyle(tokens.textSecondary)
          }.buttonStyle(PressableStyle())
        }
      } else {
        Text(t("quranOffline.mushafCount", ["count": downloads.mushafReady])).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        HStack(spacing: 10.5) {
          if downloads.mushafReady < 604 {
            AppButton(title: t("quranOffline.mushafDownload"), variant: .secondary) {
              Haptics.impact(.medium)
              downloads.downloadMushaf()
            }
          }
          if downloads.mushafBytes > 0 {
            AppButton(title: t("quranOffline.delete"), variant: .danger) {
              Haptics.impact(.light)
              AppAlert.confirm(t("quranOffline.mushafTitle"), t("quranOffline.mushafDeleteMessage"), confirmText: t("quranOffline.delete"), destructive: true) {
                downloads.deleteMushaf()
              }
            }
          }
        }
      }
    }
    .padding(17.5).frame(maxWidth: .infinity, alignment: .leading)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }

  private func audioCard(_ downloads: QuranDownloads) -> some View {
    VStack(alignment: .leading, spacing: 10.5) {
      HStack {
        Text(t("quranOffline.audioTitle")).font(.system(size: 15, weight: .semibold)).foregroundStyle(tokens.textPrimary)
        Spacer()
        if downloads.audioBytes > 0 {
          Text(t("quranOffline.size", ["size": downloads.audioBytes.formatted(.byteCount(style: .file).locale(Localizer.shared.locale))]))
            .font(.system(size: 13)).foregroundStyle(tokens.textSecondary).tabularNumbers()
        }
      }
      Text(t("quranOffline.audioHint")).font(.system(size: 13)).foregroundStyle(tokens.textSecondary)
      let items = downloads.items
      if items.isEmpty {
        Text(t("quranOffline.audioEmpty")).font(.system(size: 13, weight: .medium)).foregroundStyle(tokens.inkSubtle).padding(.vertical, 7)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(items.enumerated()), id: \.offset) { i, item in
            if i > 0 { Rectangle().fill(tokens.line).frame(height: 1) }
            let name = surahs.first { $0.id == item.surah }.map { surahName($0) } ?? "\(item.surah)"
            HStack(spacing: 10.5) {
              Text("\(item.surah)").font(.system(size: 13)).monospacedDigit().foregroundStyle(tokens.inkSubtle).frame(width: 28, alignment: .leading)
              VStack(alignment: .leading, spacing: 1.75) {
                Text(name).font(.system(size: 14, weight: .medium)).foregroundStyle(tokens.textPrimary)
                Text(QuranReciters.name(item.reciter)).font(.system(size: 12)).foregroundStyle(tokens.textSecondary)
              }.frame(maxWidth: .infinity, alignment: .leading)
              Button {
                Haptics.impact(.light)
                AppAlert.confirm(
                  t("quranOffline.deleteTitle"),
                  t("quranOffline.deleteMessage", ["surah": name, "reciter": QuranReciters.name(item.reciter)]),
                  confirmText: t("quranOffline.delete"), destructive: true
                ) { downloads.delete(surah: item.surah, reciter: item.reciter) }
              } label: {
                Ionicon("trash-outline", size: 18, color: tokens.danger).frame(width: 35, height: 35)
              }.buttonStyle(PressableStyle()).accessibilityLabel(t("quranOffline.deleteTitle"))
            }.padding(.vertical, 8.75)
          }
        }
        AppButton(title: t("quranOffline.deleteAll"), variant: .danger) {
          Haptics.impact(.light)
          AppAlert.confirm(t("quranOffline.deleteAll"), t("quranOffline.deleteAllMessage"), confirmText: t("quranOffline.delete"), destructive: true) {
            downloads.deleteAll()
          }
        }.padding(.top, 7)
      }
    }
    .padding(17.5).frame(maxWidth: .infinity, alignment: .leading)
    .background(tokens.surface, in: .rect(cornerRadius: 21))
    .overlay(RoundedRectangle(cornerRadius: 21).stroke(tokens.line, lineWidth: 1))
  }
}

private struct ProgressBarLine: View {
  @Environment(\.tokens) private var tokens
  let value: Double
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(tokens.fill)
        Capsule().fill(tokens.accent).frame(width: g.size.width * min(1, max(0, value)))
      }
    }.frame(height: 5.25)
  }
}
