import Foundation
import Combine

enum EngineStatus: Equatable {
    case paused
    case noAirPods
    case needsMotionPermission
    case needsAccessibility
    case mouseActive
    case appPaused
    case active

    var text: String {
        switch self {
        case .active: return "Aktif"
        case .paused: return "Duraklatıldı"
        case .noAirPods: return "AirPods bekleniyor (kulakta ve ses çıkışı olmalı)"
        case .needsMotionPermission: return "Hareket ve Fitness izni gerekli"
        case .needsAccessibility: return "Erişilebilirlik izni gerekli"
        case .mouseActive: return "Fare kullanılıyor (kısa duraklama)"
        case .appPaused: return "Bu uygulamada kapalı"
        }
    }

    var isGood: Bool { self == .active }
}

/// Arayüzün canlı gösterdiği durum. Motor, sadece pencere açıkken (watchers > 0) günceller.
final class LiveState: ObservableObject {
    static let shared = LiveState()

    @Published var status: EngineStatus = .noAirPods
    @Published var enabled = true
    @Published var trusted = false
    @Published var motionDenied = false

    /// Kafanın merkeze göre açısı (derece)
    @Published var yaw = 0.0
    @Published var pitch = 0.0
    @Published var roll = 0.0
    @Published var speed = 0.0
    @Published var gateOpen = false

    @Published var dwellProgress = 0.0
    @Published var clicks = 0
    @Published var scrollMode = false
    @Published var dwellSuspended = false
    @Published var pending: ClickKind = .left
    @Published var frontApp = ""

    var watchers = 0
}
