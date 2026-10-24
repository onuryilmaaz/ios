import Foundation
import Testing
import UIKit
@testable import Salah

/// Klavye kod önerisi ve yapıştırma tek değişiklikle gelir; altı hanenin tamamı yazılmalı.
@MainActor
struct OneTimeCodeTests {
  private final class Box { var value = "" }

  private func make() -> (UITextField, OneTimeCodeField.Coordinator, Box) {
    let box = Box()
    let field = OneTimeCodeField(value: .init(get: { box.value }, set: { box.value = $0 }), length: 6, focused: false) { _ in }
    let coordinator = field.makeCoordinator()
    return (UITextField(), coordinator, box)
  }

  private func insert(_ text: String, _ field: UITextField, _ c: OneTimeCodeField.Coordinator) {
    let length = (field.text ?? "").utf16.count
    if c.textField(field, shouldChangeCharactersIn: NSRange(location: length, length: 0), replacementString: text) {
      field.text = (field.text ?? "") + text
      c.changed(field)
    }
  }

  @Test func wholeCodeIsWrittenAtOnce() {
    let (field, c, box) = make()
    insert("123456", field, c)
    #expect(box.value == "123456")
  }

  @Test func suggestionWithTextAndSpacesKeepsOnlySixDigits() {
    let (field, c, box) = make()
    insert("Kodunuz: 123 4567", field, c)
    #expect(box.value == "123456")
    #expect(field.text == "123456")
  }

  @Test func typingDigitByDigitStillWorks() {
    let (field, c, box) = make()
    for d in "654321" { insert(String(d), field, c) }
    #expect(box.value == "654321")
    insert("9", field, c)
    #expect(box.value == "654321")
  }
}
