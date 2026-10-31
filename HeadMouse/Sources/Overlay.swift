import Cocoa
import QuartzCore

/// İmlecin çevresinde beliren dwell halkası / tıklama dalgası / sürükle göstergesi.
/// Fare olaylarını geçirir (ignoresMouseEvents), tüm Space'lerde ve tam ekranda görünür.
final class OverlayController {
    private let size: CGFloat
    private let window: NSWindow
    private let track = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    private var visible = false
    private var pulseUntil: TimeInterval = 0

    init() {
        let sz: CGFloat = 64
        size = sz
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: sz, height: sz),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(x: 0, y: 0, width: sz, height: sz))
        view.wantsLayer = true
        window.contentView = view

        // Tepeden başlayıp saat yönünde dolan halka
        let center = CGPoint(x: sz / 2, y: sz / 2)
        let path = CGMutablePath()
        path.addArc(center: center, radius: 20,
                    startAngle: CGFloat.pi / 2,
                    endAngle: CGFloat.pi / 2 - 2 * CGFloat.pi,
                    clockwise: true)
        let bounds = CGRect(x: 0, y: 0, width: sz, height: sz)
        for l in [track, ring, pulseLayer] {
            l.frame = bounds
            l.path = path
            l.fillColor = nil
            view.layer?.addSublayer(l)
        }
        track.strokeColor = NSColor.white.withAlphaComponent(0.55).cgColor
        track.lineWidth = 6
        track.shadowColor = NSColor.black.cgColor
        track.shadowOpacity = 0.5
        track.shadowRadius = 2
        track.shadowOffset = .zero

        ring.strokeColor = NSColor.systemBlue.cgColor
        ring.lineWidth = 4
        ring.lineCap = .round
        ring.strokeEnd = 0

        pulseLayer.strokeColor = NSColor.systemBlue.cgColor
        pulseLayer.lineWidth = 3
        pulseLayer.opacity = 0
    }

    // MARK: - Public

    func showProgress(at p: V2, progress: Double, color: NSColor) {
        configure(color: color.cgColor, strokeEnd: CGFloat(progress), showTrack: true)
        place(at: p)
    }

    /// Sürükle-kilidi açıkken imleci çevreleyen turuncu halka.
    func showDrag(at p: V2) {
        configure(color: NSColor.systemOrange.cgColor, strokeEnd: 1, showTrack: false)
        place(at: p)
    }

    func pulse(at p: V2, color: NSColor) {
        configure(color: color.cgColor, strokeEnd: 0, showTrack: false)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pulseLayer.strokeColor = color.cgColor
        CATransaction.commit()
        place(at: p)
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.6
        scale.toValue = 1.7
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.9
        fade.toValue = 0.0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseLayer.opacity = 0
        pulseLayer.add(group, forKey: "pulse")
        pulseUntil = ProcessInfo.processInfo.systemUptime + 0.45
    }

    func hide(now: TimeInterval) {
        if now < pulseUntil { return }
        if visible {
            window.orderOut(nil)
            visible = false
        }
    }

    // MARK: - Private

    private func configure(color: CGColor, strokeEnd: CGFloat, showTrack: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeColor = color
        ring.strokeEnd = strokeEnd
        track.opacity = showTrack ? 1 : 0
        CATransaction.commit()
    }

    private func place(at p: V2) {
        let x = CGFloat(p.x) - size / 2
        let y = CGFloat(Displays.shared.primaryHeight - p.y) - size / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
        if !visible {
            window.orderFrontRegardless()
            visible = true
        }
    }
}

/// Ekranın üstünde kısa süre görünen bilgi balonu ("Kaydırma modu açık" gibi).
final class HUD {
    static let shared = HUD()

    private var panel: NSPanel?
    private var label: NSTextField?
    private var work: DispatchWorkItem?

    private func ensure() {
        if panel != nil { return }
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 46),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .screenSaver
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let fx = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 320, height: 46))
        fx.material = .hudWindow
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 12
        fx.layer?.masksToBounds = true

        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .labelColor
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        fx.addSubview(l)

        p.contentView = fx
        panel = p
        label = l
    }

    func show(_ text: String, seconds: Double = 1.8) {
        guard Settings.shared.hud else { return }
        ensure()
        guard let panel = panel, let label = label else { return }

        label.stringValue = text
        let textW = label.intrinsicContentSize.width
        let h: CGFloat = 46
        let w = min(640, max(220, textW + 48))
        label.frame = NSRect(x: 24, y: (h - label.intrinsicContentSize.height) / 2,
                             width: w - 48, height: label.intrinsicContentSize.height)

        let screen = NSScreen.main ?? NSScreen.screens.first
        let f = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrame(NSRect(x: f.midX - w / 2, y: f.maxY - 76, width: w, height: h), display: true)
        panel.contentView?.frame = NSRect(x: 0, y: 0, width: w, height: h)

        work?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let item = DispatchWorkItem { [weak panel] in
            guard let panel = panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                if panel.alphaValue == 0 { panel.orderOut(nil) }
            })
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
}
