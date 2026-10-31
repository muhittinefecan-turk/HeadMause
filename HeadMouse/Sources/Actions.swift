import Cocoa

/// Bekleyerek (dwell) tıklarken hangi tıklama yapılsın?
enum ClickKind: Int, CaseIterable, Identifiable {
    case left
    case right
    case double
    case dragStart

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .left: return "Sol tık"
        case .right: return "Sağ tık"
        case .double: return "Çift tık"
        case .dragStart: return "Sürükle"
        }
    }

    var color: NSColor {
        switch self {
        case .left: return .systemBlue
        case .right: return .systemRed
        case .double: return .systemGreen
        case .dragStart: return .systemOrange
        }
    }
}

/// Bir jeste (evet, hayır, yana yatırma) atanabilecek eylemler.
enum HeadAction: String, CaseIterable, Identifiable {
    case none
    case leftClick
    case rightClick
    case doubleClick
    case dragToggle
    case recenter
    case toggleDwell
    case toggleScroll
    case pause
    case back
    case forward
    case escape
    case missionControl
    case desktopLeft
    case desktopRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Hiçbir şey"
        case .leftClick: return "Sol tık"
        case .rightClick: return "Sağ tık"
        case .doubleClick: return "Çift tık"
        case .dragToggle: return "Sürükle aç / kapat"
        case .recenter: return "Merkeze al"
        case .toggleDwell: return "Bekleyerek tıklamayı aç / kapat"
        case .toggleScroll: return "Kaydırma modunu aç / kapat"
        case .pause: return "HeadMouse'u duraklat / devam"
        case .back: return "Geri (⌘[)"
        case .forward: return "İleri (⌘])"
        case .escape: return "Esc"
        case .missionControl: return "Mission Control"
        case .desktopLeft: return "Sol masaüstüne geç"
        case .desktopRight: return "Sağ masaüstüne geç"
        }
    }
}
