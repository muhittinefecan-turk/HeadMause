import Cocoa
import ApplicationServices
import Carbon.HIToolbox

/// Kafa hareketi → imleç hareketi, dwell tıklama, jestler, kaydırma modu, sürükle-kilidi.
///
/// "Boşta kendiliğinden tıklama" sorununa karşı dört katman:
///  1. Kayma düzeltme: sensörün yavaş yaw/pitch kayması (drift) sürekli tahmin edilip çıkarılır.
///  2. Sakin kalma filtresi: kafa durgunken imleç tamamen kilitlenir; açmak için bilinçli bir hareket gerekir.
///  3. Dwell sadece BİLİNÇLİ hareketten sonra silahlanır (hızlı + yeterince uzun yol); kayma silahlandıramaz.
///  4. Tekrar tıklama kesici: aynı yerde art arda dwell tıklaması olursa dwell askıya alınır.
final class HeadMouseEngine {
    let settings = Settings.shared
    let live = LiveState.shared
    let tracker = HeadTracker()
    private let overlay = OverlayController()
    private let mouseWatch = MouseWatcher()
    private let detector = GestureDetector()
    private let displays = Displays.shared

    var onStatusChange: ((EngineStatus) -> Void)?
    private(set) var status: EngineStatus = .noAirPods
    private(set) var enabled = true

    // MARK: Sensör durumu
    private var prev: HeadSample?
    private var latest: HeadSample?
    private var neutralYaw = 0.0
    private var neutralPitch = 0.0
    private var neutralRoll = 0.0
    private var yawU = 0.0                 // sarılmamış, kayma düzeltmeli yaw (derece)
    private var lastSampleAt: TimeInterval = -100
    private var biasYaw = 0.0              // tahmini kayma (derece/sn)
    private var biasPitch = 0.0
    private var gateOpen = false
    private var gateBelowSince: TimeInterval?
    private var offYaw = 0.0               // merkeze göre açılar (derece)
    private var offPitch = 0.0
    private var offRoll = 0.0
    private var targetV = V2()             // hedef imleç hızı (px/sn)
    private var scrollTarget = 0.0         // hedef kaydırma hızı (px/sn)
    private var tiltHoldStart: TimeInterval?
    private var tiltSideRight = false
    private var tiltReady = true

    // MARK: İmleç durumu
    private var vel = V2()
    private var pos = V2()
    private var lastPosted = V2()
    private var needsSync = true
    private var holdMoveUntil: TimeInterval = 0
    private var dragging = false
    private var history: [(t: TimeInterval, p: V2)] = []

    // MARK: Dwell
    private var anchor = V2()
    private var dwellStart: TimeInterval = 0
    private var armed = false
    private var pathSinceClick = 0.0
    private var deliberateSinceClick = false
    private var lastClickPos = V2(-9999, -9999)
    private var clickableCache: Bool?
    private var pendingKind: ClickKind = .left
    private var pendingUntil: TimeInterval = 0
    private var dwellSuspended = false
    private var repeatCount = 0
    private var lastDwellClickPos = V2(-9999, -9999)
    private var lastDwellClickTime: TimeInterval = -100

    // MARK: Çift tık sayacı
    private var lastClickTime: TimeInterval = 0
    private var lastClickAt = V2(-9999, -9999)
    private var clickCount = 0

    // MARK: Kaydırma
    private var scrollMode = false
    private var scrollV = 0.0
    private var scrollAcc = 0.0

    // MARK: Uygulama kuralları
    private var frontBundle = ""
    private var appRule: AppRule?
    private var lastAppCheck: TimeInterval = -10

    // MARK: Zamanlayıcı
    private var lastTick: TimeInterval = 0
    private var lastTrustCheck: TimeInterval = -10
    private var lastLive: TimeInterval = 0
    private var trusted = false
    private var timer: DispatchSourceTimer?
    private var intervalMs = 25

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: - Yaşam döngüsü

    func start() {
        tracker.onSample = { [weak self] s in self?.handle(s) }
        tracker.start()
        trusted = AXIsProcessTrusted()
        live.trusted = trusted
        live.motionDenied = tracker.isAuthorizationDenied
        mouseWatch.startIfPossible()
        lastTick = uptime

        let t = DispatchSource.makeTimerSource(queue: .main)
        schedule(t, ms: intervalMs)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() {
        releaseDrag()
        timer?.cancel()
        timer = nil
        tracker.stop()
    }

    private func schedule(_ t: DispatchSourceTimer, ms: Int) {
        intervalMs = ms
        t.schedule(deadline: .now() + .milliseconds(ms),
                   repeating: .milliseconds(ms),
                   leeway: .milliseconds(1))
    }

    private func setInterval(_ ms: Int) {
        guard ms != intervalMs, let t = timer else { return }
        schedule(t, ms: ms)
    }

    // MARK: - Dışarıdan çağrılanlar

    func setEnabled(_ v: Bool) {
        enabled = v
        live.enabled = v
        if !v { releaseDrag() }
    }

    func toggleEnabled() {
        setEnabled(!enabled)
        playSound(enabled ? "Tink" : "Pop")
        HUD.shared.show(enabled ? "HeadMouse açık" : "HeadMouse duraklatıldı")
    }

    /// Şu anki kafa duruşunu "merkez" yapar.
    func recenter() {
        if let l = latest {
            neutralYaw = l.yaw
            neutralPitch = l.pitch
            neutralRoll = l.roll
        }
        yawU = 0
        detector.reset()
        vel = V2()
        targetV = V2()
        overlay.pulse(at: EventSynth.currentLocation(), color: .systemBlue)
        playSound("Tink")
        HUD.shared.show("Merkeze alındı")
    }

    func toggleDwell() {
        if dwellSuspended {
            dwellSuspended = false
            live.dwellSuspended = false
            settings.dwellEnabled = true
            HUD.shared.show("Bekleyerek tıklama tekrar açık")
        } else {
            settings.dwellEnabled.toggle()
            HUD.shared.show(settings.dwellEnabled ? "Bekleyerek tıklama açık" : "Bekleyerek tıklama kapalı")
        }
        playSound("Tink")
    }

    func resumeDwell() {
        dwellSuspended = false
        live.dwellSuspended = false
        HUD.shared.show("Bekleyerek tıklama tekrar açık")
    }

    func toggleScrollMode() {
        scrollMode.toggle()
        live.scrollMode = scrollMode
        vel = V2()
        targetV = V2()
        scrollV = 0
        scrollAcc = 0
        if scrollMode {
            releaseDrag()
            if let l = latest { neutralPitch = l.pitch }
            HUD.shared.show("Kaydırma modu açık — kafanı yukarı/aşağı eğ")
            playSound("Morse")
        } else {
            needsSync = true
            HUD.shared.show("Kaydırma modu kapalı")
            playSound("Pop")
        }
    }

    /// Bir sonraki dwell tıklamasının türünü belirler (12 sn içinde kullanılmazsa normale döner).
    func setNext(_ k: ClickKind) {
        setPending(k, announce: true)
    }

    private func setPending(_ k: ClickKind, announce: Bool) {
        pendingKind = k
        pendingUntil = uptime + 12
        live.pending = k
        guard announce else { return }
        HUD.shared.show(k == .left ? "Normal tıklama" : "Sonraki bekleme: \(k.title)")
        playSound("Tink")
    }

    func perform(_ a: HeadAction) {
        switch a {
        case .none: break
        case .leftClick: performClick(kind: .left, at: lastPosted)
        case .rightClick: performClick(kind: .right, at: lastPosted)
        case .doubleClick: performClick(kind: .double, at: lastPosted)
        case .dragToggle: toggleDrag()
        case .recenter: recenter()
        case .toggleDwell: toggleDwell()
        case .toggleScroll: toggleScrollMode()
        case .pause: toggleEnabled()
        case .back: EventSynth.key(kVK_ANSI_LeftBracket, flags: .maskCommand)
        case .forward: EventSynth.key(kVK_ANSI_RightBracket, flags: .maskCommand)
        case .escape: EventSynth.key(kVK_Escape, flags: [])
        case .missionControl:
            EventSynth.key(kVK_UpArrow, flags: [.maskControl, .maskSecondaryFn])
        case .desktopLeft:
            EventSynth.key(kVK_LeftArrow, flags: [.maskControl, .maskSecondaryFn])
        case .desktopRight:
            EventSynth.key(kVK_RightArrow, flags: [.maskControl, .maskSecondaryFn])
        }
    }

    // MARK: - Sensör örneği işleme (ana thread)

    private func setNeutral(_ s: HeadSample) {
        neutralYaw = s.yaw
        neutralPitch = s.pitch
        neutralRoll = s.roll
    }

    private func handle(_ s: HeadSample) {
        let rt = uptime
        lastSampleAt = rt
        defer {
            prev = s
            latest = s
        }

        guard let p = prev else {
            setNeutral(s)
            return
        }

        let dt = s.t - p.t
        if dt <= 0 || dt > 0.25 {
            // Veri kesintisi (AirPods çıkarıldı/takıldı vb.)
            targetV = V2()
            scrollTarget = 0
            detector.reset()
            if dt > 1.5 {
                setNeutral(s)
                yawU = 0
                biasYaw = 0
                biasPitch = 0
            }
            return
        }

        var wYaw = wrapPi(s.yaw - p.yaw) * radToDeg / dt      // derece/sn
        var wPitch = (s.pitch - p.pitch) * radToDeg / dt
        // İnsan kafası ~700°/sn'yi geçmez; üstü sensör sıçraması (ör. Spatial Audio yaw atlaması).
        if abs(wYaw) > 900 || abs(wPitch) > 900 { return }

        // --- 1) Kayma düzeltme: kafa neredeyse durgunken ölçülen hız = sensör kayması
        if settings.driftComp {
            if abs(wYaw - biasYaw) < 3 && abs(wPitch - biasPitch) < 3 {
                let a = 1 - exp(-dt / 1.5)
                biasYaw += (wYaw - biasYaw) * a
                biasPitch += (wPitch - biasPitch) * a
                biasYaw = max(-6, min(6, biasYaw))
                biasPitch = max(-6, min(6, biasPitch))
            }
            wYaw -= biasYaw
            wPitch -= biasPitch
        } else {
            biasYaw = 0
            biasPitch = 0
        }

        yawU += wYaw * dt
        offYaw = wrapPi(s.yaw - neutralYaw) * radToDeg
        offPitch = (s.pitch - neutralPitch) * radToDeg
        offRoll = wrapPi(s.roll - neutralRoll) * radToDeg

        // --- 2) Sakin kalma filtresi
        let speed = hypot(wYaw, wPitch)
        updateGate(speed: speed, now: rt)
        if gateOpen && speed > 9 {
            deliberateSinceClick = true
        }

        // --- İmleç / kaydırma hedef hızları
        let ix: Double = settings.invertX ? -1 : 1
        let iy: Double = settings.invertY ? -1 : 1
        var tv = V2()
        if scrollMode {
            let a = abs(offPitch)
            if a > settings.scrollDead {
                let v = pow(a - settings.scrollDead, 1.2) * settings.scrollSpeed
                let dir: Double = offPitch > 0 ? 1 : -1
                scrollTarget = dir * v * (settings.scrollInvert ? -1 : 1)
            } else {
                scrollTarget = 0
            }
        } else {
            scrollTarget = 0
            switch settings.mode {
            case .relative:
                if gateOpen {
                    // Sağa dön → yaw azalır → imleç sağa. Yukarı bak → pitch artar → imleç yukarı.
                    tv = V2(gain(-wYaw) * ix, gain(-wPitch) * settings.yScale * iy)
                }
            case .joystick:
                tv = V2(joystick(-offYaw) * ix, joystick(-offPitch) * settings.yScale * iy)
            }
            if settings.precisionKey && shiftHeld() {
                tv = V2(tv.x * settings.precisionFactor, tv.y * settings.precisionFactor)
            }
        }
        targetV = status == .active ? tv : V2()

        // --- Jestler
        let canGesture = settings.gesturesEnabled && actionsAllowed() && !scrollMode
        if canGesture {
            detector.sensitivity = settings.gestureSensitivity
            if let g = detector.push(t: rt, yaw: yawU, pitch: s.pitch * radToDeg), !dragging {
                switch g {
                case .nod(let start): runGestureAction(settings.nodAction, start: start, now: rt)
                case .shake(let start): runGestureAction(settings.shakeAction, start: start, now: rt)
                }
            }
        } else {
            detector.reset()
        }

        // --- Yana yatırma (roll) jestleri: tut → eylem
        let leftA = settings.tiltLeftAction
        let rightA = settings.tiltRightAction
        if settings.gesturesEnabled && status == .active && (leftA != .none || rightA != .none) {
            let r = settings.invertTilt ? -offRoll : offRoll
            let thr = settings.tiltAngle
            if abs(r) > thr {
                let right = r > 0
                if let start = tiltHoldStart, right == tiltSideRight {
                    if rt - start > settings.tiltHold && tiltReady {
                        tiltReady = false
                        runGestureAction(right ? rightA : leftA, start: nil, now: rt)
                    }
                } else {
                    tiltHoldStart = rt
                    tiltSideRight = right
                }
            } else {
                tiltHoldStart = nil
                if abs(r) < thr * 0.45 { tiltReady = true }
            }
        }
    }

    private func updateGate(speed: Double, now: TimeInterval) {
        let level = settings.gateLevel
        if level <= 0 {
            gateOpen = true
            gateBelowSince = nil
            return
        }
        let openThr: [Double] = [0, 5, 8, 12]
        let closeThr: [Double] = [0, 1.8, 3.0, 4.5]
        let i = min(level, 3)
        if gateOpen {
            if speed < closeThr[i] {
                if let s = gateBelowSince {
                    if now - s > 0.3 {
                        gateOpen = false
                        gateBelowSince = nil
                    }
                } else {
                    gateBelowSince = now
                }
            } else {
                gateBelowSince = nil
            }
        } else if speed > openThr[i] {
            gateOpen = true
            gateBelowSince = nil
        }
    }

    private func shiftHeld() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
    }

    /// Göreli mod: açısal hız (°/sn) → imleç hızı (px/sn). Ölü bölge + ivmelenme.
    private func gain(_ w: Double) -> Double {
        let a = abs(w)
        let dead = settings.deadzone
        if a <= dead { return 0 }
        let e = a - dead
        let v = e * settings.sensitivity * (1 + settings.accel * min(e / 60, 2.5))
        return w < 0 ? -v : v
    }

    /// Joystick modu: merkezden sapma (°) → imleç hızı (px/sn).
    private func joystick(_ o: Double) -> Double {
        let dead = 3.5
        let a = abs(o)
        if a <= dead { return 0 }
        let v = pow(a - dead, 1.25) * settings.sensitivity * 0.6
        return o < 0 ? -v : v
    }

    // MARK: - Tick (≈125 Hz hareket, ≈40 Hz boşta)

    private func tick() {
        let now = uptime
        let dt = min(max(now - lastTick, 0.001), 0.05)
        lastTick = now
        defer { publishLive(now) }

        if now - lastTrustCheck > 1.0 {
            lastTrustCheck = now
            trusted = AXIsProcessTrusted()
            live.trusted = trusted
            live.motionDenied = tracker.isAuthorizationDenied
            if trusted { mouseWatch.startIfPossible() }
        }

        if now - lastAppCheck > 0.4 {
            lastAppCheck = now
            let app = NSWorkspace.shared.frontmostApplication
            let b = app?.bundleIdentifier ?? ""
            if b != frontBundle {
                frontBundle = b
                live.frontApp = app?.localizedName ?? b
            }
            appRule = settings.appRules[b].flatMap { AppRule(rawValue: $0) }
        }

        if pendingKind != .left && now > pendingUntil {
            setPending(.left, announce: false)
        }

        let st = computeStatus(now)
        if st != status {
            status = st
            live.status = st
            if st != .active {
                releaseDrag()
                vel = V2()
                targetV = V2()
                scrollV = 0
                endDwell(now)
            } else {
                needsSync = true
            }
            onStatusChange?(st)
        }

        guard st == .active else {
            overlay.hide(now: now)
            setInterval(40)
            return
        }

        if needsSync {
            // Pasiften aktife geçerken imleç nerede ise orayı esas al;
            // yanlışlıkla tıklamamak için önce bilinçli hareket etmek gerekir.
            pos = EventSynth.currentLocation()
            lastPosted = pos.rounded
            anchor = pos
            dwellStart = now
            armed = false
            pathSinceClick = 0
            deliberateSinceClick = false
            lastClickPos = pos
            clickableCache = nil
            needsSync = false
        }

        // --- Kaydırma modu
        if scrollMode {
            overlay.hide(now: now)
            let a = 1 - exp(-dt / 0.06)
            scrollV += (scrollTarget - scrollV) * a
            if scrollTarget == 0 && abs(scrollV) < 1 { scrollV = 0 }
            scrollAcc += scrollV * dt
            let whole = Int32(scrollAcc.rounded(.towardZero))
            if whole != 0 {
                EventSynth.scroll(dy: whole)
                scrollAcc -= Double(whole)
            }
            setInterval(scrollV != 0 || scrollTarget != 0 ? 8 : 25)
            return
        }

        if now < holdMoveUntil {
            targetV = V2()
            vel = V2()
        }

        // --- Hız yumuşatma (sensör ~25-50 Hz, imleç ~125 Hz)
        let tau = max(settings.smoothingMs, 1) / 1000
        let a = 1 - exp(-dt / tau)
        vel.x += (targetV.x - vel.x) * a
        vel.y += (targetV.y - vel.y) * a
        if targetV.x == 0 && abs(vel.x) < 1 { vel.x = 0 }
        if targetV.y == 0 && abs(vel.y) < 1 { vel.y = 0 }

        let moving = !vel.isZero
        if moving {
            pos = displays.clamp(V2(pos.x + vel.x * dt, pos.y + vel.y * dt))
            pathSinceClick += hypot(vel.x, vel.y) * dt
            let rp = pos.rounded
            if rp != lastPosted {
                EventSynth.move(to: rp, dx: rp.x - lastPosted.x, dy: rp.y - lastPosted.y,
                                dragging: dragging)
                lastPosted = rp
            }
        }

        // --- 3) Dwell, sadece bilinçli hareketten sonra silahlanır
        if !armed && pathSinceClick >= 40 && deliberateSinceClick {
            armed = true
        }

        history.append((now, pos))
        while let f = history.first, now - f.t > 2.5 { history.removeFirst() }

        let dwellOn = settings.dwellEnabled && !dwellSuspended && appRule != .noDwell && actionsAllowed()
        if dragging {
            var shown = false
            if dwellOn { shown = runDwell(now, kind: .dragStart) }
            if !shown { overlay.showDrag(at: pos) }
        } else if dwellOn {
            _ = runDwell(now, kind: pendingKind)
        } else {
            endDwell(now)
            overlay.hide(now: now)
        }

        let busy = moving || !targetV.isZero || dragging
        setInterval(busy ? 8 : 25)
    }

    private func computeStatus(_ now: TimeInterval) -> EngineStatus {
        if !enabled { return .paused }
        if appRule == .pause { return .appPaused }
        if tracker.isAuthorizationDenied { return .needsMotionPermission }
        if !trusted { return .needsAccessibility }
        if now - lastSampleAt > 1.0 { return .noAirPods }
        if settings.pauseOnRealMouse && now - mouseWatch.lastExternal < settings.realMousePause {
            return .mouseActive
        }
        return .active
    }

    private func actionsAllowed() -> Bool {
        guard status == .active else { return false }
        if settings.pauseWhileTyping {
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                               eventType: .keyDown)
            if idle < 1.2 { return false }
        }
        return true
    }

    private func publishLive(_ now: TimeInterval) {
        guard live.watchers > 0, now - lastLive > 0.066 else { return }
        lastLive = now
        live.yaw = offYaw
        live.pitch = offPitch
        live.roll = offRoll
        live.gateOpen = gateOpen
        live.speed = 0
        if let l = latest, let p = prev, l.t > p.t {
            let dy = wrapPi(l.yaw - p.yaw) * radToDeg
            let dp = (l.pitch - p.pitch) * radToDeg
            live.speed = hypot(dy, dp) / (l.t - p.t)
        }
    }

    // MARK: - Dwell

    private func endDwell(_ now: TimeInterval) {
        anchor = pos
        dwellStart = now
        clickableCache = nil
        if live.dwellProgress != 0 { live.dwellProgress = 0 }
    }

    /// Halkayı gösterdiyse true döner.
    @discardableResult
    private func runDwell(_ now: TimeInterval, kind: ClickKind) -> Bool {
        // İmleç yarıçapın dışına çıktıysa sayaç sıfırlanır.
        if pos.distance(to: anchor) > settings.dwellRadius {
            anchor = pos
            dwellStart = now
            clickableCache = nil
            if live.dwellProgress != 0 { live.dwellProgress = 0 }
            if !dragging { overlay.hide(now: now) }
            return false
        }
        guard armed else {
            if !dragging { overlay.hide(now: now) }
            return false
        }

        let total = max(settings.dwellTime, 0.5)
        let showAfter = min(0.35, total * 0.4)
        let elapsed = now - dwellStart
        guard elapsed >= showAfter else {
            if !dragging { overlay.hide(now: now) }
            return false
        }

        if !dragging {
            if clickableCache == nil {
                clickableCache = settings.smartDwell ? AXProbe.isClickable(at: pos) : true
            }
            guard clickableCache == true else {
                overlay.hide(now: now)
                return false
            }
        }

        let progress = min(1, (elapsed - showAfter) / (total - showAfter))
        if live.watchers > 0 { live.dwellProgress = progress }
        var shown = false
        if settings.dwellRing {
            overlay.showProgress(at: pos, progress: progress, color: kind.color)
            shown = true
        }

        if progress >= 1 {
            fireDwell(kind: kind, now: now)
        }
        return shown
    }

    private func fireDwell(kind: ClickKind, now: TimeInterval) {
        let p = pos.rounded
        if dragging {
            releaseDrag()
            playSound("Pop")
        } else if kind == .dragStart {
            startDrag()
        } else {
            performClick(kind: kind, at: p)
        }
        if pendingKind != .left { setPending(.left, announce: false) }
        live.dwellProgress = 0

        // --- 4) Tekrar tıklama kesici
        if now - lastDwellClickTime < 15 && p.distance(to: lastDwellClickPos) < 80 {
            repeatCount += 1
        } else {
            repeatCount = 1
        }
        lastDwellClickTime = now
        lastDwellClickPos = p
        if settings.breaker && repeatCount >= 5 {
            dwellSuspended = true
            live.dwellSuspended = true
            repeatCount = 0
            HUD.shared.show("Aynı yerde tekrarlayan tıklama — bekleyerek tıklama askıda (⌃⌥D ile aç)",
                            seconds: 4)
            playSound("Basso")
        }
        afterClick(at: p)
    }

    /// Tıklamadan sonra dwell yeniden silahlanana kadar bilinçli hareket ister.
    private func afterClick(at p: V2) {
        armed = false
        pathSinceClick = 0
        deliberateSinceClick = false
        lastClickPos = p
        anchor = p
        dwellStart = uptime
        clickableCache = nil
    }

    // MARK: - Tıklama / jest / sürükleme

    private func performClick(kind: ClickKind, at p: V2) {
        let now = uptime
        switch kind {
        case .right:
            EventSynth.click(at: p, right: true, count: 1)
        case .double:
            EventSynth.click(at: p, right: false, count: 1)
            EventSynth.click(at: p, right: false, count: 2)
            clickCount = 2
        default:
            if now - lastClickTime < 1.0, p.distance(to: lastClickAt) < 8 {
                clickCount = clickCount >= 3 ? 1 : clickCount + 1
            } else {
                clickCount = 1
            }
            EventSynth.click(at: p, right: false, count: clickCount)
        }
        lastClickTime = now
        lastClickAt = p
        playSound(kind == .right ? "Pop" : "Tink")
        overlay.pulse(at: p, color: kind.color)
        live.clicks += 1
        afterClick(at: p)
    }

    private func runGestureAction(_ a: HeadAction, start: TimeInterval?, now: TimeInterval) {
        switch a {
        case .none:
            return
        case .leftClick, .rightClick, .doubleClick:
            // Jest sırasında kafa oynadığı için imleç de oynamış olabilir;
            // jest başlamadan hemen önceki konuma dönüp orada tıklarız.
            if let st = start { rewind(to: st, now: now) }
            perform(a)
        default:
            perform(a)
        }
    }

    private func rewind(to start: TimeInterval, now: TimeInterval) {
        let p = position(at: start - 0.12) ?? pos
        pos = p
        let rp = p.rounded
        EventSynth.move(to: rp, dx: rp.x - lastPosted.x, dy: rp.y - lastPosted.y, dragging: false)
        lastPosted = rp
        vel = V2()
        targetV = V2()
        holdMoveUntil = now + 0.4
        history.removeAll()
    }

    private func position(at t: TimeInterval) -> V2? {
        guard !history.isEmpty else { return nil }
        var best = history[0].p
        for h in history {
            if h.t <= t { best = h.p } else { break }
        }
        return best
    }

    private func startDrag() {
        guard !dragging else { return }
        dragging = true
        EventSynth.leftButton(down: true, at: lastPosted)
        playSound("Morse")
        afterClick(at: pos)
    }

    private func toggleDrag() {
        if dragging {
            releaseDrag()
            playSound("Pop")
        } else {
            startDrag()
        }
    }

    func releaseDrag() {
        guard dragging else { return }
        dragging = false
        EventSynth.leftButton(down: false, at: lastPosted)
    }

    private func playSound(_ name: String) {
        guard settings.sound else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
