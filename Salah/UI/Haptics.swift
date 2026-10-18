import UIKit

/// expo-haptics karşılığı; kullanım kuralları CLAUDE.md "HAPTICS" ile aynı.
enum Haptics {
  static func selection() {
    UISelectionFeedbackGenerator().selectionChanged()
  }

  static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
  }

  static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
  }
}
