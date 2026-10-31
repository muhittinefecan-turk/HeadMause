import Foundation

enum HeadGesture {
    /// Baş onaylama ("evet") → sol tık
    case nod(start: TimeInterval)
    /// Baş sallama ("hayır") → sağ tık
    case shake(start: TimeInterval)
}

/// Kafa açısı zaman serisinden "evet" / "hayır" hareketlerini bulur.
///
/// Yanlış tetiklemeyi azaltmak için üç koşul var:
///  1. Hareket hızlı ve kompakt olmalı (nod ≤ 0.95 sn, shake ≤ 1.5 sn).
///  2. Hareketten hemen önce kafa en az ~0.35 sn durgun olmalı
///     (imleci sürerken yapılan yön değişimleri jest sayılmaz).
///  3. Diğer eksen sakin kalmalı (başı çevirmek "evet" sayılmaz).
final class GestureDetector {
    // Ayarlanabilir eşikler (derece, derece/sn, saniye)
    struct Tuning {
        var nodMinAmp = 9.0
        var nodMinSpeed = 35.0
        var nodMaxDuration = 0.95
        var shakeMinAmp = 9.0
        var shakeMinSpeed = 30.0
        var shakeMaxDuration = 1.5
        var stillBeforeSpeed = 18.0
        var cooldown = 0.8
    }
    var tuning = Tuning()
    /// 1.0 = varsayılan. Büyük değer = daha küçük / yavaş hareketle de tetiklenir.
    var sensitivity = 1.0

    private struct Pt {
        let t: Double
        let yaw: Double
        let pitch: Double
    }

    private struct Leg {
        let t0: Double
        let t1: Double
        let amp: Double
        var speed: Double { amp / max(t1 - t0, 0.03) }
    }

    private var buf: [Pt] = []
    private var cooldownUntil: Double = 0

    func reset() { buf.removeAll() }

    /// yaw: sürekli (sarılmamış) derece, pitch: derece.
    func push(t: Double, yaw: Double, pitch: Double) -> HeadGesture? {
        buf.append(Pt(t: t, yaw: yaw, pitch: pitch))
        while let f = buf.first, t - f.t > 2.0 { buf.removeFirst() }
        guard t >= cooldownUntil, buf.count >= 8 else { return nil }
        let k = max(0.4, sensitivity)

        // --- Evet (nod): pitch ekseninde iki hızlı salınım
        let pitchLegs = legs(buf.map { ($0.t, $0.pitch) })
        if pitchLegs.count >= 2 {
            let l2 = pitchLegs[pitchLegs.count - 1]
            let l1 = pitchLegs[pitchLegs.count - 2]
            if l1.amp >= tuning.nodMinAmp / k,
               l2.amp >= tuning.nodMinAmp * 0.8 / k,
               l1.speed >= tuning.nodMinSpeed / k,
               l2.speed >= tuning.nodMinSpeed * 0.85 / k,
               t - l2.t1 < 0.25,
               l2.t1 - l1.t0 <= tuning.nodMaxDuration,
               range(\.yaw, from: l1.t0, to: l2.t1) < 11,
               stillBefore(l1.t0) {
                fired(at: t)
                return .nod(start: l1.t0)
            }
        }

        // --- Hayır (shake): yaw ekseninde üç hızlı salınım
        let yawLegs = legs(buf.map { ($0.t, $0.yaw) })
        if yawLegs.count >= 3 {
            let a = yawLegs[yawLegs.count - 3]
            let b = yawLegs[yawLegs.count - 2]
            let c = yawLegs[yawLegs.count - 1]
            if a.amp >= tuning.shakeMinAmp / k,
               b.amp >= tuning.shakeMinAmp / k,
               c.amp >= tuning.shakeMinAmp * 0.75 / k,
               min(a.speed, min(b.speed, c.speed)) >= tuning.shakeMinSpeed / k,
               t - c.t1 < 0.3,
               c.t1 - a.t0 <= tuning.shakeMaxDuration,
               range(\.pitch, from: a.t0, to: c.t1) < 12,
               stillBefore(a.t0) {
                fired(at: t)
                return .shake(start: a.t0)
            }
        }
        return nil
    }

    private func fired(at t: Double) {
        cooldownUntil = t + tuning.cooldown
        buf.removeAll()
    }

    /// Sinyali yön değiştirdiği noktalardan "ayaklara" (leg) böler.
    /// Son (hâlâ süren) ayak da listeye dahildir.
    private func legs(_ pts: [(Double, Double)]) -> [Leg] {
        guard pts.count > 1 else { return [] }
        let rev = 3.5   // yön değişimi sayılması için gereken ters hareket (derece)
        var out: [Leg] = []
        var pivot = 0
        var ext = 0
        var dir = 0
        var lo = 0
        var hi = 0

        // Ayağın gerçek başlangıç zamanı: pivot seviyesinden ayrıldığı an.
        func close(_ pi: Int, _ ei: Int) -> Leg {
            var j = pi
            while j < ei && abs(pts[j].1 - pts[pi].1) <= 1.5 { j += 1 }
            let start = max(pi, j - 1)
            return Leg(t0: pts[start].0, t1: pts[ei].0, amp: abs(pts[ei].1 - pts[pi].1))
        }

        for i in 1..<pts.count {
            let v = pts[i].1
            if dir == 0 {
                if v < pts[lo].1 { lo = i }
                if v > pts[hi].1 { hi = i }
                if v - pts[lo].1 >= rev {
                    dir = 1; pivot = lo; ext = i
                } else if pts[hi].1 - v >= rev {
                    dir = -1; pivot = hi; ext = i
                }
            } else {
                let d = Double(dir)
                if d * (v - pts[ext].1) > 0 {
                    ext = i
                } else if d * (pts[ext].1 - v) >= rev {
                    out.append(close(pivot, ext))
                    pivot = ext
                    dir = -dir
                    ext = i
                }
            }
        }
        if dir != 0 { out.append(close(pivot, ext)) }
        return out
    }

    private func range(_ kp: KeyPath<Pt, Double>, from a: Double, to b: Double) -> Double {
        var lo = Double.infinity
        var hi = -Double.infinity
        for p in buf where p.t >= a && p.t <= b {
            let v = p[keyPath: kp]
            lo = min(lo, v)
            hi = max(hi, v)
        }
        return hi >= lo ? hi - lo : 0
    }

    /// Hareket başlamadan hemen önce kafa durgun muydu?
    private func stillBefore(_ t0: Double) -> Bool {
        var prev: Pt?
        for p in buf where p.t >= t0 - 0.35 && p.t <= t0 + 0.02 {
            if let q = prev {
                let dt = max(p.t - q.t, 0.02)
                if abs(p.yaw - q.yaw) / dt > tuning.stillBeforeSpeed ||
                    abs(p.pitch - q.pitch) / dt > tuning.stillBeforeSpeed {
                    return false
                }
            }
            prev = p
        }
        return true
    }
}
