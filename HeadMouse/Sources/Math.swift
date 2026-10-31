import Foundation
import CoreGraphics

/// Küçük 2B vektör. CGFloat/Double karışıklığını önlemek için kullanılıyor.
struct V2: Equatable {
    var x: Double
    var y: Double

    init(_ x: Double = 0, _ y: Double = 0) {
        self.x = x
        self.y = y
    }

    init(_ p: CGPoint) {
        self.x = Double(p.x)
        self.y = Double(p.y)
    }

    static let zero = V2()

    var cg: CGPoint { CGPoint(x: x, y: y) }
    var rounded: V2 { V2(x.rounded(), y.rounded()) }
    var isZero: Bool { x == 0 && y == 0 }

    func distance(to o: V2) -> Double { hypot(x - o.x, y - o.y) }
}

/// Açıyı (-π, π] aralığına sarar.
func wrapPi(_ a: Double) -> Double {
    var v = a
    while v > Double.pi { v -= 2 * Double.pi }
    while v < -Double.pi { v += 2 * Double.pi }
    return v
}

let radToDeg = 180.0 / Double.pi
