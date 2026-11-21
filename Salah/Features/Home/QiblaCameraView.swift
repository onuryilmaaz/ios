@preconcurrency import AVFoundation
import CoreMotion
import SwiftUI

/// Kamera izni: ilk dokunuşta sorar, reddedilmişse Ayarlar'a yönlendirir.
enum QiblaCameraAccess {
  @MainActor static func request() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return true
    case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
    default:
      AppAlert.confirm(t("qibla.camera"), t("qibla.cameraDenied"), confirmText: t("qibla.openSettings")) {
        if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
      }
      return false
    }
  }
}

/// Telefon dik tutulurken arka kameranın baktığı yön (gerçek kuzeyden saat yönünde derece).
/// CLHeading ekranın üst kenarını ölçer; kamera görünümünde gereken arka kameranın ekseni.
@MainActor @Observable
final class QiblaCameraHeading {
  private(set) var upright = true
  @ObservationIgnored private let motion = CMMotionManager()
  @ObservationIgnored var onHeading: ((Double) -> Void)?

  func start() {
    guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
    let frames = CMMotionManager.availableAttitudeReferenceFrames()
    let frame: CMAttitudeReferenceFrame = frames.contains(.xTrueNorthZVertical) ? .xTrueNorthZVertical : .xMagneticNorthZVertical
    motion.deviceMotionUpdateInterval = 1 / 30
    motion.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] data, _ in
      guard let self, let m = data?.attitude.rotationMatrix else { return }
      // Satırlar cihaz eksenlerinin dünya karşılığı; kamera -z yönüne bakar. Dünya: x kuzey, y batı, z yukarı.
      let north = -m.m31, west = -m.m32, up = -m.m33
      let flat = abs(up) > 0.85
      if self.upright == flat { self.upright = !flat }
      guard !flat else { return }
      self.onHeading?(QiblaMath.normalize(atan2(-west, north) * 180 / .pi))
    }
  }

  func stop() { motion.stopDeviceMotionUpdates() }
}

/// Arka kamera önizlemesi. Görüş açısı, Kâbe işaretinin ekrandaki yerini hesaplamak için dışarı verilir.
final class QiblaCameraSession {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "salah.qibla.camera")
  private(set) var available = false
  /// Sensörün uzun kenarındaki yatay görüş açısı ve sensör en/boy oranı (uzun / kısa).
  private(set) var fieldOfView: Double = 63
  private(set) var aspect: Double = 4.0 / 3.0

  init() {
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device) else { return }
    session.beginConfiguration()
    session.sessionPreset = .high
    if session.canAddInput(input) { session.addInput(input); available = true }
    session.commitConfiguration()
    fieldOfView = Double(device.activeFormat.videoFieldOfView)
    let size = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    if size.width > 0, size.height > 0 { aspect = Double(max(size.width, size.height)) / Double(min(size.width, size.height)) }
  }

  func start() {
    guard available else { return }
    queue.async { [session] in if !session.isRunning { session.startRunning() } }
  }

  func stop() {
    queue.async { [session] in if session.isRunning { session.stopRunning() } }
  }

  /// Ekranı dolduran (aspect fill) önizlemede yatay görüş açısının yarısının tanjantı.
  func halfTangent(width: Double, height: Double) -> Double {
    let portrait = height >= width
    let sensorWidth = portrait ? 1 : aspect, sensorHeight = portrait ? aspect : 1
    let scale = max(width / sensorWidth, height / sensorHeight)
    let longTangent = tan(fieldOfView / 2 * .pi / 180)
    // Uzun kenarın yarı tanjantı `aspect` birime karşılık gelir; görünen genişlik bunun bir kesiti.
    return longTangent / aspect * (width / scale)
  }
}

private struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.backgroundColor = .black
    view.preview.session = session
    view.preview.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ view: PreviewView, context: Context) {
    // Duo/iPad yatayda önizleme ekranla aynı yöne döner.
    guard let connection = view.preview.connection else { return }
    let landscape = view.bounds.width > view.bounds.height
    let angle: CGFloat = landscape ? (view.window?.windowScene?.interfaceOrientation == .landscapeLeft ? 180 : 0) : 90
    if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
  }
}

/// Kamera görüntüsü üstünde Kâbe işareti: kameranın yönüne göre yatayda kayar, ekran dışındaysa kenarda ok gösterir.
struct QiblaCameraView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let theme: QiblaTheme
  // Gövde her pusula okumasında yeniden kurulur; oturum yalnız ilk açılışta oluşur.
  @State private var camera: QiblaCameraSession?
  @State private var heading: QiblaCameraHeading?
  private var store: QiblaStore { .shared }

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width, height = geometry.size.height
      let alignment = store.alignment
      let half = camera?.halfTangent(width: width, height: height) ?? tan(25 * .pi / 180)
      let upright = heading?.upright ?? true
      let offset = abs(alignment.delta) < 89 ? tan(alignment.delta * .pi / 180) / half * width / 2 : .infinity * (alignment.delta < 0 ? -1 : 1)
      let visible = abs(offset) < width / 2 - 36
      ZStack {
        if let camera, camera.available {
          CameraPreview(session: camera.session).ignoresSafeArea()
        } else if camera != nil {
          Forest.s950.ignoresSafeArea()
          Text(t("qibla.cameraUnavailable")).font(.system(size: 15)).foregroundStyle(.white)
            .multilineTextAlignment(.center).padding(.horizontal, 32)
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 110)
        }
        Rectangle().fill(.white.opacity(0.7)).frame(width: 1.5, height: min(height * 0.36, 280))
          .accessibilityHidden(true)
        if store.state == .ready && upright {
          if visible {
            marker(aligned: alignment.aligned)
              .offset(x: offset)
              .animation(reduceMotion ? nil : .interactiveSpring(response: 0.25), value: offset)
          } else {
            edgeArrow(right: alignment.delta > 0)
              .frame(maxWidth: .infinity, alignment: alignment.delta > 0 ? .trailing : .leading)
              .padding(.horizontal, 14)
          }
        }
        if store.state == .locating {
          Text(t("qibla.locating")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Forest.s950.opacity(0.7), in: .rect(cornerRadius: 16))
        } else if !upright {
          Text(t("qibla.holdUpright")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Forest.s950.opacity(0.7), in: .rect(cornerRadius: 16))
            .padding(.horizontal, 32)
        }
      }
      .frame(width: width, height: height)
      // Coğrafi sağ/sol RTL'de aynalanmaz.
      .environment(\.layoutDirection, .leftToRight)
    }
    .background(Color.black)
    .onAppear {
      let session = camera ?? QiblaCameraSession()
      let motion = heading ?? QiblaCameraHeading()
      camera = session
      heading = motion
      motion.onHeading = { store.setCameraHeading($0) }
      motion.start()
      session.start()
    }
    .onDisappear {
      heading?.stop()
      camera?.stop()
      store.setCameraHeading(nil)
    }
  }

  private func marker(aligned: Bool) -> some View {
    VStack(spacing: 8) {
      ZStack(alignment: .top) {
        RoundedRectangle(cornerRadius: 9).fill(Forest.s950)
        Rectangle().fill(Gold.s300).frame(height: 5).padding(.top, 11)
      }
      .frame(width: 52, height: 52)
      .clipShape(.rect(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).stroke(aligned ? Gold.s300 : .white, lineWidth: aligned ? 3 : 1.5))
      .scaleEffect(aligned && !reduceMotion ? 1.12 : 1)
      .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: aligned)
      Text(t("qibla.kaaba")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Forest.s950.opacity(0.7), in: .capsule)
    }
    .accessibilityHidden(true)
  }

  private func edgeArrow(right: Bool) -> some View {
    Ionicon(right ? "chevron-forward" : "chevron-back", size: 26, color: .white)
      .frame(width: 52, height: 52)
      .background(theme.accent, in: .circle)
      .accessibilityHidden(true)
  }
}
