import Foundation
import Combine

enum PointerMode: Int {
    /// Jiroskop gibi: kafanın dönme HIZI imleci sürer. Kayma (drift) sorunu yok.
    case relative = 0
    /// Joystick gibi: kafanın merkezden sapması imleç hızını belirler.
    case joystick = 1
}

/// Uygulama bazlı kural: bu uygulama öndeyken HeadMouse ne yapsın?
enum AppRule: String, CaseIterable, Identifiable {
    case pause
    case noDwell

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pause: return "HeadMouse kapalı"
        case .noDwell: return "Bekleyerek tıklama kapalı"
        }
    }
}

private func udDouble(_ k: String, _ def: Double) -> Double {
    UserDefaults.standard.object(forKey: k) as? Double ?? def
}
private func udBool(_ k: String, _ def: Bool) -> Bool {
    UserDefaults.standard.object(forKey: k) as? Bool ?? def
}
private func udInt(_ k: String, _ def: Int) -> Int {
    UserDefaults.standard.object(forKey: k) as? Int ?? def
}
private func udAction(_ k: String, _ def: HeadAction) -> HeadAction {
    if let raw = UserDefaults.standard.string(forKey: k), let a = HeadAction(rawValue: raw) {
        return a
    }
    return def
}

/// Tüm ayarlar. Değişiklikler hem arayüze (SwiftUI) hem UserDefaults'a yansır.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    // MARK: İmleç
    @Published var mode: PointerMode { didSet { d.set(mode.rawValue, forKey: "mode") } }
    /// Kafanın 1 derecelik dönüşü için imlecin gideceği piksel.
    @Published var sensitivity: Double { didSet { d.set(sensitivity, forKey: "pxPerDeg") } }
    /// Dikey hareket çarpanı (yukarı-aşağı bakış genelde daha dar olduğundan).
    @Published var yScale: Double { didSet { d.set(yScale, forKey: "yScale") } }
    @Published var accel: Double { didSet { d.set(accel, forKey: "accel") } }
    @Published var smoothingMs: Double { didSet { d.set(smoothingMs, forKey: "smoothingMs") } }
    /// Bu açısal hızın (derece/sn) altındaki hareketler yok sayılır.
    @Published var deadzone: Double { didSet { d.set(deadzone, forKey: "deadzone") } }
    /// 0 kapalı, 1 düşük, 2 orta, 3 yüksek
    @Published var gateLevel: Int { didSet { d.set(gateLevel, forKey: "gateLevel") } }
    @Published var driftComp: Bool { didSet { d.set(driftComp, forKey: "driftComp") } }
    @Published var invertX: Bool { didSet { d.set(invertX, forKey: "invertX") } }
    @Published var invertY: Bool { didSet { d.set(invertY, forKey: "invertY") } }
    @Published var precisionKey: Bool { didSet { d.set(precisionKey, forKey: "precisionKey") } }
    @Published var precisionFactor: Double { didSet { d.set(precisionFactor, forKey: "precisionFactor") } }

    // MARK: Tıklama (dwell)
    @Published var dwellEnabled: Bool { didSet { d.set(dwellEnabled, forKey: "dwellEnabled") } }
    @Published var dwellTime: Double { didSet { d.set(dwellTime, forKey: "dwellTime") } }
    @Published var dwellRadius: Double { didSet { d.set(dwellRadius, forKey: "dwellRadius") } }
    @Published var dwellRing: Bool { didSet { d.set(dwellRing, forKey: "dwellRing") } }
    @Published var smartDwell: Bool { didSet { d.set(smartDwell, forKey: "smartDwell") } }
    @Published var breaker: Bool { didSet { d.set(breaker, forKey: "breaker") } }

    // MARK: Jestler
    @Published var gesturesEnabled: Bool { didSet { d.set(gesturesEnabled, forKey: "gesturesEnabled") } }
    @Published var gestureSensitivity: Double { didSet { d.set(gestureSensitivity, forKey: "gestureSensitivity") } }
    @Published var nodAction: HeadAction { didSet { d.set(nodAction.rawValue, forKey: "nodAction") } }
    @Published var shakeAction: HeadAction { didSet { d.set(shakeAction.rawValue, forKey: "shakeAction") } }
    @Published var tiltLeftAction: HeadAction { didSet { d.set(tiltLeftAction.rawValue, forKey: "tiltLeftAction") } }
    @Published var tiltRightAction: HeadAction { didSet { d.set(tiltRightAction.rawValue, forKey: "tiltRightAction") } }
    @Published var tiltAngle: Double { didSet { d.set(tiltAngle, forKey: "tiltAngle") } }
    @Published var tiltHold: Double { didSet { d.set(tiltHold, forKey: "tiltHold") } }
    @Published var invertTilt: Bool { didSet { d.set(invertTilt, forKey: "invertTilt") } }

    // MARK: Kaydırma
    @Published var scrollSpeed: Double { didSet { d.set(scrollSpeed, forKey: "scrollSpeed") } }
    @Published var scrollDead: Double { didSet { d.set(scrollDead, forKey: "scrollDead") } }
    @Published var scrollInvert: Bool { didSet { d.set(scrollInvert, forKey: "scrollInvert") } }

    // MARK: Güvenlik
    @Published var pauseWhileTyping: Bool { didSet { d.set(pauseWhileTyping, forKey: "pauseWhileTyping") } }
    @Published var pauseOnRealMouse: Bool { didSet { d.set(pauseOnRealMouse, forKey: "pauseOnRealMouse") } }
    @Published var realMousePause: Double { didSet { d.set(realMousePause, forKey: "realMousePause") } }

    // MARK: Genel
    @Published var sound: Bool { didSet { d.set(sound, forKey: "sound") } }
    @Published var hud: Bool { didSet { d.set(hud, forKey: "hud") } }
    @Published var firstRunDone: Bool { didSet { d.set(firstRunDone, forKey: "firstRunDone") } }
    /// bundleID → AppRule.rawValue
    @Published var appRules: [String: String] { didSet { d.set(appRules, forKey: "appRules") } }

    private init() {
        mode = PointerMode(rawValue: udInt("mode", 0)) ?? .relative
        sensitivity = udDouble("pxPerDeg", 70)
        yScale = udDouble("yScale", 1.25)
        accel = udDouble("accel", 0.8)
        smoothingMs = udDouble("smoothingMs", 35)
        deadzone = udDouble("deadzone", 1.2)
        gateLevel = udInt("gateLevel", 1)
        driftComp = udBool("driftComp", true)
        invertX = udBool("invertX", false)
        invertY = udBool("invertY", false)
        precisionKey = udBool("precisionKey", true)
        precisionFactor = udDouble("precisionFactor", 0.3)

        dwellEnabled = udBool("dwellEnabled", true)
        dwellTime = udDouble("dwellTime", 1.0)
        dwellRadius = udDouble("dwellRadius", 14)
        dwellRing = udBool("dwellRing", true)
        smartDwell = udBool("smartDwell", false)
        breaker = udBool("breaker", true)

        gesturesEnabled = udBool("gesturesEnabled", true)
        gestureSensitivity = udDouble("gestureSensitivity", 1.0)
        nodAction = udAction("nodAction", .leftClick)
        shakeAction = udAction("shakeAction", .rightClick)
        tiltLeftAction = udAction("tiltLeftAction", .none)
        tiltRightAction = udAction("tiltRightAction", .none)
        tiltAngle = udDouble("tiltAngle", 22)
        tiltHold = udDouble("tiltHold", 0.6)
        invertTilt = udBool("invertTilt", false)

        scrollSpeed = udDouble("scrollSpeed", 40)
        scrollDead = udDouble("scrollDead", 6)
        scrollInvert = udBool("scrollInvert", false)

        pauseWhileTyping = udBool("pauseWhileTyping", true)
        pauseOnRealMouse = udBool("pauseOnRealMouse", true)
        realMousePause = udDouble("realMousePause", 0.9)

        sound = udBool("sound", true)
        hud = udBool("hud", true)
        firstRunDone = udBool("firstRunDone", false)
        appRules = (UserDefaults.standard.dictionary(forKey: "appRules") as? [String: String]) ?? [:]
    }
}
