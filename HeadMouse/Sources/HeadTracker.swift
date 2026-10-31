import Foundation
import CoreMotion

struct HeadSample {
    /// CMDeviceMotion.timestamp (saniye). Sadece örnekler arası fark (dt) için kullanılır.
    let t: TimeInterval
    /// Radyan. yaw: dikey eksen etrafında dönme, pitch: yukarı/aşağı, roll: omuza yatırma.
    let yaw: Double
    let pitch: Double
    let roll: Double
}

/// AirPods'un kafa hareketi sensörünü (CMHeadphoneMotionManager) okur.
final class HeadTracker: NSObject, CMHeadphoneMotionManagerDelegate {
    private let manager = CMHeadphoneMotionManager()
    var onSample: ((HeadSample) -> Void)?

    /// Hareket izni reddedildi mi?
    var isAuthorizationDenied: Bool {
        let s = CMHeadphoneMotionManager.authorizationStatus()
        return s == .denied || s == .restricted
    }

    func start() {
        manager.delegate = self
        // isDeviceMotionAvailable'a güvenmiyoruz: AirPods takılı değilken false dönebilir.
        // Güncellemeleri her durumda başlatıyoruz; AirPods kulağa takılınca veri akmaya başlar.
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }
            if error != nil { return }
            guard let m = motion else { return }
            self.onSample?(HeadSample(t: m.timestamp,
                                      yaw: m.attitude.yaw,
                                      pitch: m.attitude.pitch,
                                      roll: m.attitude.roll))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    // Bağlantı bilgisi sadece bilgi amaçlı; asıl durum "örnek geliyor mu?" ile belirlenir.
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {}
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {}
}
