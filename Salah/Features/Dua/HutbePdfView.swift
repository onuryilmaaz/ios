import PDFKit
import SwiftUI

/// Hutbenin özgün PDF'i uygulama içinde (kaydırma, yakınlaştırma PDFKit'ten).
struct HutbePdfView: View {
  @Environment(\.tokens) private var tokens
  @Environment(\.dismiss) private var dismiss
  let item: HutbeParser.Item
  let lang: HutbeService.Lang

  @State private var document: PDFDocument?
  @State private var failed = false
  @State private var attempt = 0

  var body: some View {
    VStack(spacing: 0) {
      StandardHeader(title: item.title)
      if let document {
        PDFKitView(document: document, background: UIColor(tokens.canvas))
          .ignoresSafeArea(edges: .bottom)
      } else if failed {
        failedView
      } else {
        Spacer()
        ProgressView().tint(tokens.accent)
        Text(t("common.loading")).font(.system(size: 14)).foregroundStyle(tokens.textSecondary).padding(.top, 12)
        Spacer()
      }
    }
    .background(tokens.canvas)
    .task(id: attempt) { await load() }
  }

  private var failedView: some View {
    VStack(spacing: 0) {
      Spacer()
      Ionicon("document-text-outline", size: 44, color: tokens.inkSubtle)
      Text(t("hutbe.pdfFailed")).font(.system(size: 15)).foregroundStyle(tokens.textSecondary)
        .multilineTextAlignment(.center).padding(.top, 16).padding(.horizontal, 32)
      AppButton(title: t("common.retry")) { attempt += 1 }
        .frame(width: 180).padding(.top, 20)
      Spacer()
      if let raw = item.pdfUrl, let url = URL(string: raw) {
        AppButton(title: t("hutbe.openBrowser"), variant: .outline) {
          Haptics.impact(.light)
          InAppBrowser.open(url)
        }
        .padding(.horizontal, 16).padding(.bottom, 32)
      }
    }
  }

  private func load() async {
    failed = false
    do {
      let file = try await HutbeService.pdfFile(lang, item: item)
      guard !Task.isCancelled else { return }
      if let loaded = PDFDocument(url: file) {
        document = loaded
      } else {
        try? FileManager.default.removeItem(at: file)
        failed = true
      }
    } catch {
      if !Task.isCancelled { failed = true }
    }
  }
}

private struct PDFKitView: UIViewRepresentable {
  let document: PDFDocument
  let background: UIColor

  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.autoScales = true
    view.backgroundColor = background
    view.document = document
    return view
  }

  func updateUIView(_ view: PDFView, context: Context) {
    view.backgroundColor = background
  }
}
