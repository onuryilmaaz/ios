import UIKit
import UserNotifications
import UserNotificationsUI

/// Ayet/hadis bildirimlerine basılı tutunca açılan özel görünüm.
///
/// iOS'un varsayılan genişletilmiş görünümü uzun metni kırpar; bu extension
/// (SMS'in tam metni göstermek için kullandığı mekanizmanın aynısı) bildirimin
/// data yükündeki TAM metni — ayetlerde Arapçasıyla birlikte — gösterir.
/// Hangi bildirimlerde devreye gireceği Info.plist'teki
/// UNNotificationExtensionCategory ("spiritual_reminder") ile eşleşir.
class NotificationViewController: UIViewController, UNNotificationContentExtension {

  private let scrollView = UIScrollView()
  private let stack = UIStackView()
  private let titleLabel = UILabel()
  private let arabicLabel = UILabel()
  private let bodyLabel = UILabel()
  private let sourceLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    titleLabel.font = .systemFont(ofSize: 13, weight: .black)
    titleLabel.textColor = .secondaryLabel
    titleLabel.numberOfLines = 1

    arabicLabel.font = .systemFont(ofSize: 22, weight: .regular)
    arabicLabel.textColor = .label
    arabicLabel.numberOfLines = 0
    arabicLabel.textAlignment = .right

    bodyLabel.font = .systemFont(ofSize: 16, weight: .medium)
    bodyLabel.textColor = .label
    bodyLabel.numberOfLines = 0

    sourceLabel.font = .systemFont(ofSize: 12, weight: .bold)
    sourceLabel.textColor = UIColor(red: 0.098, green: 0.361, blue: 0.275, alpha: 1) // accent-700
    sourceLabel.numberOfLines = 1

    stack.axis = .vertical
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false
    [titleLabel, arabicLabel, bodyLabel, sourceLabel].forEach { stack.addArrangedSubview($0) }

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stack)
    view.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 14),
      stack.leadingAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -14),
      stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
    ])
  }

  func didReceive(_ notification: UNNotification) {
    let content = notification.request.content
    let info = content.userInfo

    // Tam metin data yükünde taşınır; eski format bildirimlerde content.body'ye düş.
    let fullBody = (info["body"] as? String) ?? content.body
    let arabic = (info["arabic"] as? String) ?? ""
    let source = (info["subtitle"] as? String) ?? content.subtitle

    titleLabel.text = content.title.uppercased()
    bodyLabel.text = "“\(fullBody)”"
    sourceLabel.text = source

    if arabic.isEmpty {
      arabicLabel.isHidden = true
    } else {
      arabicLabel.isHidden = false
      arabicLabel.text = arabic
    }

    // Yüksekliği İÇERİĞE göre öner — kırpma yok. Metin ne kadar uzunsa boy o
    // kadar büyür; ekranı aşarsa sistem genişletilmiş bildirimi kendisi
    // kaydırır. (Eski 560pt tavanı uzun ayet/hadisleri kesiyordu; interaction
    // kapalı olduğundan iç scroll da devreye girmiyordu.) Aşırı değerlere karşı
    // yalnızca güvenlik amaçlı geniş bir üst sınır bırakıyoruz.
    view.layoutIfNeeded()
    let targetWidth = view.bounds.width > 0 ? view.bounds.width - 32 : 300
    let fit = stack.systemLayoutSizeFitting(
      CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    preferredContentSize = CGSize(width: view.bounds.width, height: min(fit.height + 28, 2000))
  }
}
