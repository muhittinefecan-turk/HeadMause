import SwiftUI
import ServiceManagement
import AppKit

// MARK: - Ana pencere

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Genel"
    case pointer = "İmleç"
    case click = "Tıklama"
    case gestures = "Jestler"
    case scroll = "Kaydırma"
    case safety = "Güvenlik"
    case apps = "Uygulamalar"
    case about = "Kısayollar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gauge.with.dots.needle.67percent"
        case .pointer: return "cursorarrow.motionlines"
        case .click: return "cursorarrow.click.2"
        case .gestures: return "face.smiling"
        case .scroll: return "arrow.up.and.down.text.horizontal"
        case .safety: return "shield.lefthalf.filled"
        case .apps: return "square.grid.2x2"
        case .about: return "keyboard"
        }
    }
}

// @State bir Swift makrosu; sadece Command Line Tools ile derlerken eklenti bulunamıyor.
// Bu yüzden basit ObservableObject + @StateObject kullanıyoruz.
final class TabModel: ObservableObject {
    @Published var tab: SettingsTab? = .general
}

struct SettingsRootView: View {
    let engine: HeadMouseEngine
    @StateObject private var model = TabModel()

    private var tab: SettingsTab? { model.tab }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $model.tab) {
                ForEach(SettingsTab.allCases) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            Divider()

            Group {
                switch tab ?? .general {
                case .general: GeneralTab(engine: engine)
                case .pointer: PointerTab()
                case .click: ClickTab(engine: engine)
                case .gestures: GesturesTab()
                case .scroll: ScrollTab(engine: engine)
                case .safety: SafetyTab()
                case .apps: AppsTab()
                case .about: ShortcutsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 600)
    }
}

// MARK: - Ortak parçalar

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = ""
    var format: String = "%.0f"
    var help: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value) + unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
            if let h = help {
                Text(h).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ActionPicker: View {
    let title: String
    @Binding var selection: HeadAction

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(HeadAction.allCases) { a in
                Text(a.title).tag(a)
            }
        }
    }
}

struct HeadPad: View {
    @ObservedObject var live: LiveState

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 12),
                       with: .color(Color.secondary.opacity(0.5)), lineWidth: 1)

            var cross = Path()
            cross.move(to: CGPoint(x: size.width / 2, y: 0))
            cross.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            cross.move(to: CGPoint(x: 0, y: size.height / 2))
            cross.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(cross, with: .color(Color.secondary.opacity(0.25)), lineWidth: 1)

            let range = 30.0
            let cx = size.width / 2
            let cy = size.height / 2
            // Sağa dönünce yaw azalır → nokta sağa. Yukarı bakınca pitch artar → nokta yukarı.
            let x = cx - CGFloat(max(-range, min(range, live.yaw)) / range) * cx
            let y = cy - CGFloat(max(-range, min(range, live.pitch)) / range) * cy
            let dot = CGRect(x: x - 7, y: y - 7, width: 14, height: 14)
            ctx.fill(Path(ellipseIn: dot),
                     with: .color(live.gateOpen ? Color.green : Color.orange))
        }
        .frame(width: 170, height: 170)
    }
}

final class TestCounts: ObservableObject {
    @Published var counts = Array(repeating: 0, count: 8)
}

struct TestPad: View {
    @StateObject private var model = TestCounts()

    var body: some View {
        let counts = model.counts
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                      spacing: 8) {
                ForEach(0..<8, id: \.self) { i in
                    Button {
                        model.counts[i] += 1
                    } label: {
                        Text("\(counts[i])").frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                    .tint(counts[i] > 0 ? Color.green : nil)
                }
            }
            HStack {
                Text("Toplam: \(counts.reduce(0, +))").foregroundStyle(.secondary)
                Spacer()
                Button("Sıfırla") { model.counts = Array(repeating: 0, count: 8) }
            }
        }
    }
}

// MARK: - Genel

struct GeneralTab: View {
    let engine: HeadMouseEngine
    @ObservedObject private var live = LiveState.shared
    @ObservedObject private var s = Settings.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Circle()
                        .fill(live.status.isGood ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(live.status.text).font(.headline)
                    Spacer()
                    Toggle("Aktif", isOn: Binding(get: { live.enabled },
                                                  set: { engine.setEnabled($0) }))
                        .toggleStyle(.switch)
                }
                if live.dwellSuspended {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Tekrarlayan tıklama algılandı, bekleyerek tıklama askıda.")
                        Spacer()
                        Button("Tekrar aç") { engine.resumeDwell() }
                    }
                }
                if live.scrollMode {
                    HStack {
                        Image(systemName: "arrow.up.and.down").foregroundStyle(.blue)
                        Text("Kaydırma modu açık")
                        Spacer()
                        Button("Kapat") { engine.toggleScrollMode() }
                    }
                }
            }

            if !live.trusted || live.motionDenied {
                Section("Kurulum") {
                    if !live.trusted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Erişilebilirlik izni gerekli (imleci sürmek için)")
                            Spacer()
                            Button("İzin ver…") {
                                SystemPanes.requestAccessibility()
                                SystemPanes.open("Privacy_Accessibility")
                            }
                        }
                    }
                    if live.motionDenied {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Hareket ve Fitness izni gerekli (AirPods sensörü için)")
                            Spacer()
                            Button("Ayarları aç…") { SystemPanes.open("Privacy_Motion") }
                        }
                    }
                    Text("İzin verdikten sonra uygulamayı kapatıp yeniden aç.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Kafa hareketi (canlı)") {
                HStack(alignment: .top, spacing: 20) {
                    HeadPad(live: live)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "Yatay: %+.1f°", live.yaw))
                        Text(String(format: "Dikey: %+.1f°", live.pitch))
                        Text(String(format: "Yana eğim: %+.1f°", live.roll))
                        Text(String(format: "Hız: %.0f °/sn", live.speed))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(live.gateOpen ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(live.gateOpen ? "Hareket açık" : "Sakin (kilitli)")
                        }
                        if !live.frontApp.isEmpty {
                            Text("Öndeki uygulama: \(live.frontApp)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .monospacedDigit()
                    Spacer()
                }
                HStack {
                    Button("Merkeze al") { engine.recenter() }
                    Text("Başın rahat durduğunda bas.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Deneme alanı") {
                TestPad()
                Text("İmleci bir kutunun üzerinde beklet ya da evet/hayır başı yap; sayaç artar. Boşta artıyorsa Güvenlik sekmesindeki filtreyi yükselt.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Geri bildirim") {
                Toggle("Ses", isOn: $s.sound)
                Toggle("Ekranda bilgi balonu", isOn: $s.hud)
            }
        }
        .formStyle(.grouped)
        .onAppear { live.watchers += 1 }
        .onDisappear { live.watchers = max(0, live.watchers - 1) }
    }
}

// MARK: - İmleç

struct PointerTab: View {
    @ObservedObject private var s = Settings.shared

    private var screenWidth: Double {
        Double(NSScreen.main?.frame.width ?? 1440)
    }

    var body: some View {
        Form {
            Section("Hareket") {
                Picker("Mod", selection: $s.mode) {
                    Text("Göreli (jiroskop)").tag(PointerMode.relative)
                    Text("Joystick").tag(PointerMode.joystick)
                }
                .pickerStyle(.segmented)
                Text(s.mode == .relative
                     ? "Kafanı çevirdikçe imleç gider, durunca durur. Kayma yapmaz; önerilen."
                     : "Kafanı merkezden ne kadar çevirirsen imleç o kadar hızlı gider, merkeze dönünce durur.")
                    .font(.caption).foregroundStyle(.secondary)

                SliderRow(title: "Hız (piksel / derece)", value: $s.sensitivity,
                          range: 15...250, step: 1,
                          help: "Ekranı baştan sona geçmek için yaklaşık \(Int(screenWidth / max(s.sensitivity, 1)))° baş dönüşü yeter. Daha az baş hareketi istiyorsan artır.")
                SliderRow(title: "Dikey çarpan", value: $s.yScale,
                          range: 0.5...2.5, step: 0.05, unit: "×", format: "%.2f",
                          help: "Yukarı-aşağı bakış genelde daha dar olduğu için dikeyi biraz güçlendirir.")
                SliderRow(title: "İvmelenme", value: $s.accel,
                          range: 0...2, step: 0.05, format: "%.2f",
                          help: "Hızlı hareketlerde imleç daha da hızlanır; yavaşta hassas kalır.")
            }

            Section("Titreme ve kayma") {
                SliderRow(title: "Yumuşatma", value: $s.smoothingMs,
                          range: 0...150, step: 5, unit: " ms",
                          help: "Yüksek = daha akıcı ama biraz gecikmeli.")
                SliderRow(title: "Ölü bölge", value: $s.deadzone,
                          range: 0...6, step: 0.1, unit: " °/sn", format: "%.1f",
                          help: "Bu hızın altındaki küçük kıpırtılar yok sayılır.")
                Picker("Sakin kalma filtresi", selection: $s.gateLevel) {
                    Text("Kapalı").tag(0)
                    Text("Düşük").tag(1)
                    Text("Orta").tag(2)
                    Text("Yüksek").tag(3)
                }
                .pickerStyle(.segmented)
                Text("Kafa durgunken imleci tamamen kilitler; yeniden hareket için küçük ama net bir kıpırtı yeter. Boşta imleç sürükleniyorsa yükselt, çok küçük hareketler algılanmıyorsa düşür.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Otomatik kayma düzeltme", isOn: $s.driftComp)
                Text("AirPods sensörünün yavaş kaymasını sürekli tahmin edip çıkarır.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Yön") {
                Toggle("Yatay yönü ters çevir", isOn: $s.invertX)
                Toggle("Dikey yönü ters çevir", isOn: $s.invertY)
            }

            Section("Hassas mod") {
                Toggle("⇧ Shift basılıyken imleci yavaşlat", isOn: $s.precisionKey)
                if s.precisionKey {
                    SliderRow(title: "Yavaşlatma", value: $s.precisionFactor,
                              range: 0.1...0.8, step: 0.05, unit: "×", format: "%.2f")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tıklama

struct ClickTab: View {
    let engine: HeadMouseEngine
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var live = LiveState.shared

    var body: some View {
        Form {
            Section("Bekleyerek tıkla (dwell)") {
                Toggle("Açık", isOn: $s.dwellEnabled)
                SliderRow(title: "Bekleme süresi", value: $s.dwellTime,
                          range: 0.5...3, step: 0.1, unit: " sn", format: "%.1f",
                          help: "İmleç kıpırdamadan bu kadar durunca tıklar. İlk ~0.35 sn halka görünmez.")
                SliderRow(title: "Sabit kalma alanı", value: $s.dwellRadius,
                          range: 6...40, step: 1, unit: " px",
                          help: "İmleç bu yarıçapın dışına çıkarsa sayaç sıfırlanır.")
                Toggle("Dolan halkayı göster", isOn: $s.dwellRing)
                Toggle("Akıllı dwell (sadece tıklanabilir öğelerde, deneysel)", isOn: $s.smartDwell)
                Text("Buton, link gibi öğelerin üstünde tıklar; boş alanlarda tıklamaz. Bazı uygulamalar (ör. Chrome) erişilebilirlik bilgisini kapalı tutar; o zaman her yerde tıklar.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Sonraki bekleme tıklaması") {
                HStack {
                    ForEach(ClickKind.allCases) { k in
                        Button(k.title) { engine.setNext(k) }
                            .tint(live.pending == k ? k.color.swiftUI : nil)
                    }
                }
                Text("Seçtiğin tür bir sonraki bekleme tıklamasında kullanılır, sonra normal tıka döner (12 sn içinde kullanılmazsa da). Halka rengi türü gösterir: mavi sol, kırmızı sağ, yeşil çift, turuncu sürükle. Sürükle seçilince bekleme tıkı tuşu basılı tutar, bir sonraki bekleme bırakır.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Koruma") {
                Toggle("Tekrarlayan tıklamada dwell'i askıya al", isOn: $s.breaker)
                Text("Aynı bölgede 15 sn içinde 5 bekleme tıklaması olursa dwell durur ve bilgi verir. ⌃⌥D ile ya da Genel sekmesinden devam ettirebilirsin.")
                    .font(.caption).foregroundStyle(.secondary)
                if live.dwellSuspended {
                    Button("Dwell'i tekrar aç") { engine.resumeDwell() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private extension NSColor {
    var swiftUI: Color { Color(nsColor: self) }
}

// MARK: - Jestler

struct GesturesTab: View {
    @ObservedObject private var s = Settings.shared

    var body: some View {
        Form {
            Section("Baş jestleri") {
                Toggle("Jestleri etkinleştir", isOn: $s.gesturesEnabled)
                SliderRow(title: "Algılama hassasiyeti", value: $s.gestureSensitivity,
                          range: 0.5...1.8, step: 0.05, unit: "×", format: "%.2f",
                          help: "Yüksek = daha küçük hareketle tetiklenir (kazara tetiklenme artabilir).")
            }

            Section("Eylemler") {
                ActionPicker(title: "Evet (başı aşağı-yukarı)", selection: $s.nodAction)
                ActionPicker(title: "Hayır (başı sağa-sola, 3 kez)", selection: $s.shakeAction)
                Text("Jestin sayılması için hareketten önce başın ~0.35 sn durgun olması gerekir; imleci sürerken yaptığın yön değişimleri jest sayılmaz. Tıklama eylemleri, imleç kafa hareketiyle kaymış olsa bile jestten hemen önceki konumda yapılır.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Başı yana yatır ve tut") {
                ActionPicker(title: "Sola yatır", selection: $s.tiltLeftAction)
                ActionPicker(title: "Sağa yatır", selection: $s.tiltRightAction)
                SliderRow(title: "Açı", value: $s.tiltAngle,
                          range: 12...40, step: 1, unit: "°")
                SliderRow(title: "Tutma süresi", value: $s.tiltHold,
                          range: 0.3...1.5, step: 0.05, unit: " sn", format: "%.2f")
                Toggle("Sağ/sol yönünü ters çevir", isOn: $s.invertTilt)
                Text("Yana yatırma varsayılan olarak kapalı. Örn. sağa yatır = sürükle aç/kapat, sola yatır = geri yapabilirsin.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Kaydırma

struct ScrollTab: View {
    let engine: HeadMouseEngine
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var live = LiveState.shared

    var body: some View {
        Form {
            Section("Kaydırma modu") {
                HStack {
                    Button(live.scrollMode ? "Kaydırma modunu kapat" : "Kaydırma modunu aç") {
                        engine.toggleScrollMode()
                    }
                    Text("veya ⌃⌥S").foregroundStyle(.secondary)
                }
                Text("Açıkken imleç durur, kafanı yukarı/aşağı eğdikçe sayfa kayar. Açtığın andaki duruşun merkez kabul edilir; ne kadar eğersen o kadar hızlı kayar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Ayarlar") {
                SliderRow(title: "Hız", value: $s.scrollSpeed, range: 10...150, step: 5)
                SliderRow(title: "Ölü bölge", value: $s.scrollDead,
                          range: 2...15, step: 0.5, unit: "°", format: "%.1f")
                Toggle("Yönü ters çevir", isOn: $s.scrollInvert)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Güvenlik

struct SafetyTab: View {
    @ObservedObject private var s = Settings.shared

    var body: some View {
        Form {
            Section("Otomatik duraklama") {
                Toggle("Yazı yazarken tıklamaları ve jestleri duraklat", isOn: $s.pauseWhileTyping)
                Toggle("Gerçek fare / trackpad kullanılınca duraklat", isOn: $s.pauseOnRealMouse)
                if s.pauseOnRealMouse {
                    SliderRow(title: "Duraklama süresi", value: $s.realMousePause,
                              range: 0.3...3, step: 0.1, unit: " sn", format: "%.1f")
                }
                Text("AirPods'u kulaktan çıkarınca ya da çıkış cihazı değişince HeadMouse kendiliğinden durur.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Boşta kendiliğinden tıklıyorsa") {
                Label("İmleç > Sakin kalma filtresi: Orta veya Yüksek yap", systemImage: "1.circle")
                Label("İmleç > Otomatik kayma düzeltme açık olsun", systemImage: "2.circle")
                Label("Tıklama > Bekleme süresini uzat (1.3 sn+)", systemImage: "3.circle")
                Label("Gerekirse ⌃⌥D ile dwell'i kapat, jestlerle tıkla", systemImage: "4.circle")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Uygulamalar

struct AppsTab: View {
    @ObservedObject private var s = Settings.shared

    private func appName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            return name.replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func runningApps() -> [NSRunningApplication] {
        let me = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular &&
            $0.bundleIdentifier != nil &&
            $0.bundleIdentifier != me
        }
    }

    var body: some View {
        Form {
            Section("Uygulama kuralları") {
                if s.appRules.isEmpty {
                    Text("Henüz kural yok. Örn. bir oyunda HeadMouse'u tamamen kapatabilir ya da sadece bekleyerek tıklamayı kapatabilirsin.")
                        .foregroundStyle(.secondary)
                }
                ForEach(s.appRules.keys.sorted(), id: \.self) { id in
                    HStack {
                        Text(appName(id))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { AppRule(rawValue: s.appRules[id] ?? "") ?? .pause },
                            set: { s.appRules[id] = $0.rawValue }
                        )) {
                            ForEach(AppRule.allCases) { r in
                                Text(r.title).tag(r)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        Button {
                            s.appRules.removeValue(forKey: id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Menu("Uygulama ekle…") {
                    ForEach(runningApps(), id: \.processIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                            if let id = app.bundleIdentifier, s.appRules[id] == nil {
                                s.appRules[id] = AppRule.pause.rawValue
                            }
                        }
                    }
                }
                Text("Listede sadece şu an açık olan uygulamalar görünür.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Kısayollar / Hakkında

final class LaunchModel: ObservableObject {
    @Published var on = SMAppService.mainApp.status == .enabled
}

struct ShortcutsTab: View {
    @StateObject private var launchModel = LaunchModel()

    private func setLaunch(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("HeadMouse: giriş öğesi ayarlanamadı: \(error)")
        }
    }

    var body: some View {
        Form {
            Section("Genel kısayollar") {
                LabeledContent("⌃⌥H", value: "Duraklat / devam")
                LabeledContent("⌃⌥C", value: "Merkeze al")
                LabeledContent("⌃⌥D", value: "Bekleyerek tıklamayı aç / kapat (askıdaysa devam ettir)")
                LabeledContent("⌃⌥S", value: "Kaydırma modu aç / kapat")
                LabeledContent("⌃⌥R", value: "Sonraki bekleme = sağ tık")
                LabeledContent("⌃⌥F", value: "Sonraki bekleme = çift tık")
                LabeledContent("⌃⌥G", value: "Sonraki bekleme = sürükle")
                LabeledContent("⌃⌥,", value: "Bu pencereyi aç")
                LabeledContent("⇧ basılıyken", value: "İmleç yavaşlar (hassas mod)")
            }

            Section("Uygulama") {
                Toggle("Girişte otomatik başlat", isOn: $launchModel.on)
                    .onChange(of: launchModel.on) { _, new in setLaunch(new) }
                HStack {
                    Button("Erişilebilirlik ayarları…") { SystemPanes.open("Privacy_Accessibility") }
                    Button("Hareket ve Fitness ayarları…") { SystemPanes.open("Privacy_Motion") }
                }
                LabeledContent("Sürüm", value: "0.2.0")
            }
        }
        .formStyle(.grouped)
    }
}
