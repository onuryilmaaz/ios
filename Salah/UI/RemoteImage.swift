import SwiftUI
import UIKit

/// Önbellekli uzak görsel. SwiftUI `AsyncImage` ilk istek iptal olursa ya da
/// düşerse bir daha denemiyor (açılışta ilk çizilen başlıkta avatar boş kalıyordu);
/// bu görünüm bellek önbelleğinden anında gösterir, yoksa birkaç kez yeniden dener.
struct RemoteImage<Placeholder: View>: View {
  let url: URL?
  @ViewBuilder var placeholder: Placeholder
  @State private var image: UIImage?

  init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
    self.url = url
    self.placeholder = placeholder()
    _image = State(initialValue: url.flatMap { RemoteImageCache.shared.object(forKey: $0 as NSURL) })
  }

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        placeholder
      }
    }
    .task(id: url) { await load() }
  }

  private func load() async {
    guard let url else {
      image = nil
      return
    }
    if let cached = RemoteImageCache.shared.object(forKey: url as NSURL) {
      image = cached
      return
    }
    for attempt in 0..<4 {
      if Task.isCancelled { return }
      if let (data, response) = try? await URLSession.shared.data(from: url),
        (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
        let loaded = UIImage(data: data)
      {
        RemoteImageCache.shared.setObject(loaded, forKey: url as NSURL)
        image = loaded
        return
      }
      try? await Task.sleep(for: .seconds(Double(attempt + 1) * 1.5))
    }
  }
}

enum RemoteImageCache {
  static let shared: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.countLimit = 64
    return cache
  }()
}

/// Oturumdaki kullanıcının profil fotoğrafı; yoksa kişi simgesi.
struct UserAvatar: View {
  var iconColor: Color

  var body: some View {
    let auth = AuthStore.shared
    let url = auth.isAuthenticated ? auth.user?.avatarUrl.flatMap(URL.init(string:)) : nil
    RemoteImage(url: url) { Ionicon("person", size: 18, color: iconColor) }
  }
}
