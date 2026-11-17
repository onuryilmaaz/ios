import SwiftUI
import UIKit

/// Mushaf sayfa çevirme: kağıt kıvrılması (UIPageViewController `.pageCurl`).
/// Tek sayfada cilt sağda (sayfa soldan kalkıp sağa döner): UIKit'in soldan sağa kitabı yatayda aynalanır,
/// sayfaların içeriği geri aynalanır. Kitap düzeninde (Duo açık, yatay) cilt ortada,
/// yaprak arkalı önlü: sağda tek, solda çift sayfa.
/// UIKit sırayı soldan sağa artan sayar; Mushaf sağdan sola ilerlediği için kitap düzeninde sıra ters verilir.
struct MushafCurlPager: UIViewControllerRepresentable {
  @Binding var page: Int
  let book: Bool
  let pageView: (Int) -> AnyView

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> UIPageViewController {
    let spine: UIPageViewController.SpineLocation = book ? .mid : .min
    let pager = UIPageViewController(
      transitionStyle: .pageCurl, navigationOrientation: .horizontal,
      options: [.spineLocation: NSNumber(value: spine.rawValue)])
    pager.isDoubleSided = book
    pager.dataSource = context.coordinator
    pager.delegate = context.coordinator
    pager.view.backgroundColor = .clear
    if !book { pager.view.transform = CGAffineTransform(scaleX: -1, y: 1) }
    // Kenara dokunmak sayfa çevirmez: dokunuş üst çubuğu açar/kapar, ayet ve kelime seçer.
    for recognizer in pager.gestureRecognizers where recognizer is UITapGestureRecognizer { recognizer.isEnabled = false }
    pager.setViewControllers(context.coordinator.controllers(for: page), direction: .forward, animated: false)
    return pager
  }

  func updateUIViewController(_ pager: UIPageViewController, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self
    for case let host as MushafPageHost in pager.viewControllers ?? [] { host.show(pageView(host.page)) }
    let shown = coordinator.shownPages(pager)
    // Sure seçimi, işaret, dinleme gibi dışarıdan gelen sayfa değişimi de kağıt gibi çevrilir.
    guard !coordinator.turning, !shown.isEmpty, !shown.contains(page) else { return }
    let forward = page > (shown.min() ?? page)
    pager.setViewControllers(coordinator.controllers(for: page), direction: coordinator.direction(forward: forward), animated: true)
  }

  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    var parent: MushafCurlPager
    var turning = false

    init(_ parent: MushafCurlPager) { self.parent = parent }

    /// UIKit'in "sonraki" yaprağı: kitap düzeninde küçük numara (sağa doğru), tek sayfada büyük numara.
    private func neighbor(of page: Int, after: Bool) -> Int {
      parent.book ? (after ? page - 1 : page + 1) : (after ? page + 1 : page - 1)
    }

    func direction(forward: Bool) -> UIPageViewController.NavigationDirection {
      parent.book ? (forward ? .reverse : .forward) : (forward ? .forward : .reverse)
    }

    func host(_ page: Int) -> UIViewController? {
      (1...604).contains(page) ? MushafPageHost(page: page, rootView: parent.pageView(page), mirrored: !parent.book) : nil
    }

    /// Ekrana konacak yapraklar: kitap düzeninde [sol (çift), sağ (tek)].
    func controllers(for page: Int) -> [UIViewController] {
      guard parent.book else { return [host(page)].compactMap { $0 } }
      let right = page % 2 == 1 ? page : page - 1
      return [host(right + 1), host(right)].compactMap { $0 }
    }

    func shownPages(_ pager: UIPageViewController) -> [Int] {
      (pager.viewControllers ?? []).compactMap { ($0 as? MushafPageHost)?.page }
    }

    func pageViewController(_ pager: UIPageViewController, viewControllerBefore controller: UIViewController) -> UIViewController? {
      guard let page = (controller as? MushafPageHost)?.page else { return nil }
      return host(neighbor(of: page, after: false))
    }

    func pageViewController(_ pager: UIPageViewController, viewControllerAfter controller: UIViewController) -> UIViewController? {
      guard let page = (controller as? MushafPageHost)?.page else { return nil }
      return host(neighbor(of: page, after: true))
    }

    func pageViewController(_ pager: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
      turning = true
    }

    func pageViewController(_ pager: UIPageViewController, didFinishAnimating finished: Bool,
      previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
      turning = false
      guard completed, let shown = shownPages(pager).min() else { return }
      // Kitap düzeninde açık sayfa sağdaki (tek) sayfadır.
      if parent.page != shown { parent.page = shown }
    }
  }
}

/// Tek Mushaf sayfasını barındırır; güvenli alan boşluğunu sayfa kendisi verir.
final class MushafPageHost: UIHostingController<AnyView> {
  let page: Int
  /// Tek sayfa düzeninde sayfalayıcı aynalı: içerik geri çevrilir.
  let mirrored: Bool

  init(page: Int, rootView: AnyView, mirrored: Bool) {
    self.page = page
    self.mirrored = mirrored
    super.init(rootView: mirrored ? AnyView(rootView.scaleEffect(x: -1, y: 1)) : rootView)
    safeAreaRegions = []
    view.backgroundColor = .clear
  }

  func show(_ view: AnyView) { rootView = mirrored ? AnyView(view.scaleEffect(x: -1, y: 1)) : view }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
