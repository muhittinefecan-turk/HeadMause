<div align="center">

# HeadMouse

**Mac'inin imlecini AirPods ile kontrol et. Başını oynat, imleç gelsin. Sabit tut, tıklasın.**

AirPods'un içindeki hareket sensörlerini kullanan, eller serbest ve kamerasız bir kafa işaretçisi (head pointer).

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-ready-black)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

[English](README.md) · [Türkçe](README.tr.md)

</div>

<!-- Ayarlar penceresinin ekran görüntüsünü ekleyip bu satırı aç:
<p align="center"><img src="docs/settings.png" width="760" alt="HeadMouse ayarlar penceresi"></p>
-->

## Nedir?

HeadMouse, AirPods'taki kafa takibi sensörünü fareye çeviren küçük bir menü çubuğu uygulamasıdır:

- **Başını çevir**, imleç takip etsin. Birkaç derecelik hareket tüm ekranı geçebilir.
- **İmleci sabit tut**, halka dolsun ve tıklasın. Sanki zihninle tıklıyormuşsun gibi.
- **Evet** diye başını sallayarak sol tık, **hayır** diye sallayarak sağ tık yap, ya da jestlere istediğin eylemleri ata.

Kamera yok, ışık sorunu yok, bulut yok. Her şey Mac'inde çalışır.

Eller serbest girişi denemek isteyenler için yapıldı; fare ya da trackpad kullanmakta zorlanan herkese de yardımı dokunabilir. Erken aşamada, deneysel bir projedir; sertifikalı bir yardımcı cihaz değildir.

## Özellikler

**İmleç**
- Göreli (jiroskop gibi) ve joystick modu
- "Derece başına piksel" hız ayarı; ne kadar az hareket edeceğini sen seçersin
- İvmelenme, yumuşatma, ölü bölge, ayrı dikey çarpan
- **Kayma düzeltme** ve **sakin kalma filtresi**: sen durunca imleç de durur
- Hassas iş için ⇧ basılıyken imleç yavaşlar

**Tıklama**
- İlerleme halkalı **dwell tıklama**: sabit tut, tıklasın
- Dwell sadece bilinçli bir hareketten sonra silahlanır; oturup beklerken kendiliğinden tıklamaz
- Bir sorun çıkarsa dwell'i askıya alan tekrar tıklama kesici
- Tek kısayolla "sonraki bekleme sağ tık / çift tık / sürükle olsun"
- Sadece buton ve linklerde tıklayan isteğe bağlı akıllı dwell

**Baş jestleri**
- Evet, hayır, sola ve sağa yatırma; her biri istediğin eyleme bağlanır
- Eylemler: sol/sağ/çift tık, sürükle kilidi, geri, ileri, Esc, Mission Control, masaüstü geçişi, kaydırma modu, duraklat ve daha fazlası
- Tıklama jestleri, başın oynamadan *önceki* konuma tıklar

**Diğer**
- Kafa eğimiyle kaydırma modu
- Uygulama kuralları: belirli uygulamalarda HeadMouse'u ya da dwell'i kapat
- Ayarlar penceresinde canlı kafa hareketi görünümü ve deneme alanı
- Yazı yazarken, gerçek fare kullanırken ve AirPods kulaktan çıkınca otomatik duraklar
- Genel kısayollu menü çubuğu uygulaması

## Gereksinimler

- **macOS 14 (Sonoma) veya üstü** bir Mac
- Kafa takibi olan AirPods: **AirPods Pro (2. nesil ve sonrası), AirPods Max, ANC'li AirPods 4** ve Spatial Audio kafa takibi destekleyen diğer modeller. AirPods 4 (ANC) ve MacBook Air M4 üzerinde geliştirildi.
- Xcode Command Line Tools (tam Xcode gerekmez)

> Destek, Apple'ın `CMHeadphoneMotionManager` API'sine bağlıdır. AirPods'un hareket verisi vermiyorsa HeadMouse onlarla çalışamaz.

## Kurulum

```bash
xcode-select --install       # bir kez, Command Line Tools yoksa
git clone https://github.com/<kullanici-adin>/HeadMouse.git
cd HeadMouse
./build.sh install           # derler, /Applications'a kopyalar ve açar
```

Sadece derlemek için `./build.sh`, sonra `open build/HeadMouse.app`.

### İzinler

HeadMouse iki izin ister. İkisi de Mac'inde kalır.

| İzin | Neden |
|---|---|
| **Erişilebilirlik** | İmleci hareket ettirmek ve tıklamak için |
| **Hareket ve Fitness** | AirPods kafa sensörünü okumak için |

Ayarlar penceresindeki **Genel** sekmesi neyin eksik olduğunu gösterir ve doğru yere götürür. Erişilebilirlik iznini verdikten sonra HeadMouse bir saniye içinde fark eder.

Kendin derlersen uygulama sabit bir kimlikle geçici (ad-hoc) imzalanır; böylece Erişilebilirlik izni yeniden derlemede kaybolmaz. Kendi sertifikanla imzalamak için: `SIGN_ID="Apple Development: Adın (XXXX)" ./build.sh`.

## Kullanım

1. AirPods'u tak ve Mac'in **ses çıkışı** olarak seç. Kafa verisi ancak çıkış cihazı olarak bağlıyken akar.
2. Menü çubuğundaki ikona tıkla ya da `⌃⌥,` ile ayarlar penceresini aç.
3. **Genel** sekmesinde noktanın kafanı takip ettiğini kontrol et. Rahat otururken **Merkeze al**'a bas.
4. İmleci kafanı çevirerek hareket ettir. Sabit tutunca tıklar, başını sallayınca sol tık yapar.
5. İmleç ters yöne gidiyorsa **İmleç → Yön**'den çevir.

### Kısayollar

| Kısayol | İş |
|---|---|
| `⌃⌥H` | Duraklat / devam |
| `⌃⌥C` | Merkeze al |
| `⌃⌥D` | Dwell tıklamayı aç / kapa (askıdaysa devam ettirir) |
| `⌃⌥S` | Kaydırma modu |
| `⌃⌥R` / `⌃⌥F` / `⌃⌥G` | Sonraki bekleme sağ tık / çift tık / sürükle |
| `⌃⌥,` | Ayarlar |
| `⇧` basılı | İmleç yavaşlar (hassas mod) |

## Ayar ipuçları

- **Başını daha az oynatmak istiyorsan** **İmleç → Hız (piksel / derece)** değerini artır. Slider, ekranı geçmek için kaç derece gerektiğini gösterir.
- **İmleç kayıyor ya da kendiliğinden tıklıyorsa** **Sakin kalma filtresini** Orta ya da Yüksek yap, kayma düzeltmeyi açık tut, dwell süresini uzat.
- **Çok küçük hareketler algılanmıyorsa** sakin kalma filtresini ve ölü bölgeyi düşür.
- **Kazara jest çok oluyorsa** **Jestler** sekmesinde hassasiyeti düşür.

## Nasıl çalışıyor

1. `CMHeadphoneMotionManager`, AirPods'tan yaw, pitch ve roll akıtır.
2. Motor açının *değişimini* (derece/sn) alır, sensörün yavaş kaymasını çıkarır, sakin kalma kapısı, ölü bölge ve ivmelenme eğrisinden geçirip imleç hızına çevirir.
3. Hız yumuşatılır ve en fazla 125 Hz'de sistem fare olayı (`CGEvent`) olarak gönderilir.
4. Dwell, jestler ve kaydırma modu bunun üstünde çalışır. Jest algılayıcı açı sinyalinde evet ve hayır hareketlerini bulur, ancak hemen öncesinde kafa durgunsa sayar.

Kaynak yapısı: `Sources/` içinde `HeadTracker`, `Engine`, `GestureDetector`, `Overlay` (halka ve ekran mesajları), `System` (olaylar, erişilebilirlik yardımcıları), `Settings` ve `SettingsUI` (SwiftUI) bulunur.

## Sorun giderme

| Sorun | Çözüm |
|---|---|
| İzin açık olduğu halde "Erişilebilirlik izni gerekli" | Erişilebilirlik listesinden HeadMouse'u **−** ile sil, sonra `tccutil reset Accessibility com.muhittinefecanturk.headmouse` çalıştır, uygulamayı yeniden aç ve tekrar izin ver |
| "AirPods bekleniyor" | Kulakta, bağlı ve ses çıkışı olarak seçili olmalı |
| Hiçbir şey hareket etmiyor | **Genel** sekmesinde iki izni de kontrol et |
| İmleç ters gidiyor | **İmleç → Yön** |
| Kendiliğinden duruyor ("gerçek fare kullanılıyor") | **Güvenlik** sekmesinde o seçeneği kapat ya da trackpad'e dokunma |
| Sağa/sola yatırma ters | **Jestler → Sağ/sol yönünü ters çevir** |

## Gizlilik

HeadMouse'ta ağ kodu yoktur, hiçbir şey toplamaz ve sadece ayarlarını macOS kullanıcı varsayılanlarında saklar. Kafa hareketi verisi Mac'inin belleğinde işlenir; hiçbir yere kaydedilmez ya da gönderilmez.

## Durum ve yol haritası

Erken sürüm (0.2). Tek bir kurulumda geliştirildi ve kullanıldı; pürüzler olabilir, bir şey ters giderse lütfen issue aç.

- [ ] Kalibrasyon sihirbazı
- [ ] Ayarları dışa / içe aktarma
- [ ] Yatay kaydırma
- [ ] Hazır, noter onaylı (notarized) sürüm

## Teşekkür

[PodsControlMac](https://github.com/sumionochi/PodsControlMac) ve MacPaw'ın [kulaklıkla kafa işaretleme](https://research.macpaw.com/publications/headphones-accessibility) araştırmasından ilham alındı. HeadMouse bağımsız bir projedir ve Apple ile bağlantılı değildir.

## Lisans

[MIT](LICENSE)
