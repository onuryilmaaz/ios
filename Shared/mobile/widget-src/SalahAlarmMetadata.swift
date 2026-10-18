import Foundation

#if canImport(AlarmKit)
import AlarmKit

/// Uygulamanın kurduğu AlarmKit alarmlarına eşlik eden veri. Hem uygulamada
/// (alarm kurulurken) hem widget'ta (ertele geri sayımı Live Activity'si)
/// derlenir; iki tarafta da aynı tip olmalı.
@available(iOS 26.0, *)
struct SalahAlarmMetadata: AlarmMetadata {
  /// prayer | tahajjud | sahur | custom
  var kind: String
  /// Vakit alarmlarında widget kimliği (sabah, ogle, ...); diğerlerinde boş.
  var prayerId: String
}
#endif
