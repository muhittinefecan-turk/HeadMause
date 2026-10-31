# HeadMouse 🎧🖱️

[![Swift](https://img.shields.io/badge/Swift-5-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+%20|%20Apple%20Silicon-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com)
[![AirPods](https://img.shields.io/badge/AirPods-Head%20Tracking-1d1d1f?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)
[![Privacy](https://img.shields.io/badge/Privacy-Camera--Free%20%7C%20On--Device-blueviolet?style=for-the-badge)](#-gizlilik)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

> **AirPods'unun Kafa Takibi Sensörüyle Mac İmlecini Kontrol Eden, Kamerasız ve Eller Serbest Kafa İşaretçisi (Head Pointer).**

Developed with ❤️ by **Muhittin Efecan Türk**

[English](README.en.md) · **Türkçe**

---

## 🌟 Genel Bakış

**HeadMouse**, AirPods'un içindeki hareket sensörlerini (jiroskop ve ivmeölçer) okuyup Mac imlecine çeviren küçük bir menü çubuğu uygulamasıdır. **Başını çevir**, imleç gelsin. **Sabit tut**, halka dolsun ve tıklasın. Sanki zihninle tıklıyormuşsun gibi.

Kamera kullanmaz; bu yüzden ışık koşullarından ve oturuş pozisyonundan etkilenmez. Hiçbir veri Mac'inden çıkmaz.

```
+------------------+                                  +--------------------+
|     AirPods      | ~ ~ [ Kafa Hareketi ] ~ ~ ~ ~ > |  HeadMouse (Mac)   |
|  (CoreMotion)    |     yaw / pitch / roll           |  Filtre → Motor    |
+------------------+                                  +--------------------+
                                                                |
                                                  İmleç · Tıklama · Kaydırma
```

> ⚠️ Erken aşamada, deneysel bir projedir. Sertifikalı bir yardımcı cihaz (assistive device) değildir.

---

## 🚀 Temel Yetenekler ve Özellikler

### 1. 🎯 Küçük Hareketle Hassas İmleç
- **Göreli (jiroskop gibi) ve joystick modu:** Göreli modda kafanın dönme *hızı* imleci sürer; durunca imleç durur.
- **Derece başına piksel hız ayarı:** Ekranı geçmek için kaç derece başını çevireceğini sen seçersin. Ayarlar penceresi bunu canlı gösterir.
- İvmelenme, yumuşatma, ölü bölge ve ayrı dikey çarpan.
- **⇧ basılıyken hassas mod:** İmleç yavaşlar, ince işlere uygun.

### 2. 🖱️ Dwell Tıklama ve Baş Jestleri
- **Dwell (bekleyerek tıkla):** İmleci sabit tut, ilerleme halkası dolsun, tıklasın. Süre ve sabit kalma alanı ayarlanabilir.
- **Evet / hayır başı:** Varsayılan olarak sol ve sağ tık. Sola ve sağa yatırma da atanabilir.
- **Sonraki bekleme türü:** Tek kısayolla bir sonraki dwell'i sağ tık, çift tık ya da sürükle yap. Halka rengi türü gösterir.
- Tıklama jestleri, başın oynamasından *önceki* konuma tıklar; kafayı sallarken imleç kaysa bile doğru yere basar.
- İsteğe bağlı **akıllı dwell:** Sadece buton ve link gibi tıklanabilir öğelerde tıklar.

### 3. 🛡️ Boşta Kendiliğinden Tıklamaya Karşı 4 Katman
AirPods sensörü zamanla çok yavaş "kayar" (drift). Bu kayma imleci sürükleyip dwell'i tetikleyebilir. HeadMouse buna karşı dört katmanla korunur:

| Katman | Ne yapar |
| :--- | :--- |
| **Kayma düzeltme** | Kafa durgunken ölçülen hızı sensör kayması sayıp sürekli çıkarır |
| **Sakin kalma filtresi** | Kafa durgunken imleci kilitler; yeniden hareket için net bir kıpırtı ister |
| **Bilinçli hareket şartı** | Her tıklamadan sonra dwell, ancak hızlı bir hareket ve yeterli yoldan sonra yeniden silahlanır |
| **Tekrar tıklama kesici** | Aynı bölgede art arda tıklama olursa dwell'i askıya alır ve uyarır |

### 4. 🧩 Eylemler, Kaydırma ve Uygulama Kuralları
- **Jestlere atanabilen eylemler:** Sol / sağ / çift tık, sürükle kilidi, geri (⌘[), ileri (⌘]), Esc, Mission Control, masaüstü geçişi, kaydırma modu, duraklat.
- **Kaydırma modu:** Kafanı yukarı/aşağı eğdikçe sayfa kayar.
- **Uygulama kuralları:** Belirli uygulamalarda HeadMouse'u ya da sadece dwell'i kapat.

### 5. 🖥️ Tam Ayarlar Penceresi (SwiftUI)
- 8 sekme: **Genel, İmleç, Tıklama, Jestler, Kaydırma, Güvenlik, Uygulamalar, Kısayollar**.
- **Canlı kafa görünümü:** Yatay, dikey, yana eğim, hız ve "hareket açık/kilitli" durumu anında görünür.
- **Deneme alanı:** Dwell ve jestleri ayar yaparken kutulara tıklayarak dene.
- Yazı yazarken, gerçek fare kullanırken ve AirPods kulaktan çıkınca **otomatik duraklama**.
- Genel kısayollar, ses ve ekran bilgi balonu, girişte otomatik başlatma.

---

## 🏗️ Proje Mimarisi

```
HeadMouse/
├── Info.plist                # Bundle kimliği, LSUIElement (menü çubuğu uygulaması)
├── build.sh                  # Xcode'suz derleme + imzalama + kurulum
├── LICENSE
├── README.md / README.en.md
└── Sources/
    ├── main.swift            # Giriş noktası
    ├── AppController.swift   # Menü çubuğu, ayarlar penceresi, genel kısayollar
    ├── Engine.swift          # Kafa hareketi → imleç, dwell, jestler, kaydırma, koruma katmanları
    ├── HeadTracker.swift     # CMHeadphoneMotionManager ile AirPods sensör okuyucu
    ├── GestureDetector.swift # Evet / hayır başı algılayıcı
    ├── Overlay.swift         # Dwell halkası ve ekran bilgi balonu (HUD)
    ├── System.swift          # CGEvent üretimi, fare izleme, erişilebilirlik yardımcıları
    ├── Settings.swift        # Kalıcı ayarlar (ObservableObject + UserDefaults)
    ├── SettingsUI.swift      # SwiftUI ayarlar arayüzü
    ├── LiveState.swift       # Arayüzün canlı gösterdiği durum
    ├── Actions.swift         # Tıklama türleri ve jestlere atanabilen eylemler
    ├── HotKeys.swift         # Genel kısayollar (Carbon)
    └── Math.swift            # Küçük yardımcılar
```

---

## ⚙️ Hareket Hattı Özeti

| Aşama | Açıklama |
| :--- | :--- |
| **Sensör** | `CMHeadphoneMotionManager` yaw / pitch / roll akıtır |
| **Hız** | Açının *değişimi* (derece/sn) hesaplanır; sıçramalar (>900°/sn) atılır |
| **Kayma düzeltme** | Durgun kafadaki ölçüm sensör kayması olarak çıkarılır |
| **Sakin kalma kapısı** | Yeterince hızlı hareket yoksa imleç kilitli kalır |
| **Eğri** | Ölü bölge + ivmelenme ile piksel/sn hıza çevrilir |
| **Yumuşatma** | Sensör ~25–50 Hz, imleç ~125 Hz; ara değerler yumuşatılır |
| **Çıkış** | Sistem fare olayları (`CGEvent`) olarak gönderilir |

---

## 🛠️ Kurulum ve Derleme

### Gereksinimler
- **macOS:** macOS 14 (Sonoma) veya üzeri, Apple Silicon önerilir
- **AirPods:** Kafa takibi destekleyen model; **AirPods Pro (2. nesil ve sonrası), AirPods Max, ANC'li AirPods 4** ve Spatial Audio kafa takibi olan diğerleri. AirPods 4 (ANC) ve MacBook Air M4 üzerinde geliştirildi.
- **Xcode Command Line Tools** (tam Xcode gerekmez)

> Destek, Apple'ın `CMHeadphoneMotionManager` API'sine bağlıdır. AirPods'un hareket verisi vermiyorsa HeadMouse onlarla çalışamaz.

### Adım Adım Kurulum

1. **Depoyu Klonlayın:**
   ```bash
   git clone https://github.com/muhittinefecanturk/HeadMouse.git
   cd HeadMouse
   ```

2. **Command Line Tools'u Kurun** (yoksa):
   ```bash
   xcode-select --install
   ```

3. **Derleyin ve Kurun:**
   ```bash
   ./build.sh install     # derler, /Applications'a kopyalar ve açar
   ```
   *(Sadece derlemek için `./build.sh`, sonra `open build/HeadMouse.app`.)*

4. **İzinleri Verin:**

   | İzin | Neden |
   | :--- | :--- |
   | **Erişilebilirlik** | İmleci hareket ettirmek ve tıklamak için |
   | **Hareket ve Fitness** | AirPods kafa sensörünü okumak için |

   Ayarlar penceresindeki **Genel** sekmesi neyin eksik olduğunu gösterir ve doğru yere götürür. Erişilebilirlik iznini verdikten sonra HeadMouse bir saniye içinde fark eder.

5. **(İsteğe bağlı) Kendi Sertifikanla İmzala:**
   ```bash
   SIGN_ID="Apple Development: Adın (XXXX)" ./build.sh install
   ```
   *Varsayılan olarak uygulama sabit bir kimlikle geçici (ad-hoc) imzalanır; böylece Erişilebilirlik izni yeniden derlemede kaybolmaz.*

---

## 📱 Kullanım Kılavuzu

### İlk Çalıştırma
1. AirPods'u tak ve Mac'in **ses çıkışı** olarak seç. Kafa verisi ancak çıkış cihazı olarak bağlıyken akar.
2. Menü çubuğundaki ikondan ya da `⌃⌥,` ile ayarlar penceresini aç.
3. **Genel** sekmesinde noktanın kafanı takip ettiğini gör. Rahat otururken **Merkeze al**'a bas.
4. İmleç ters gidiyorsa **İmleç → Yön**'den çevir.

### Günlük Kullanım
- **Sür:** Kafanı çevir, imleç gelsin.
- **Tıkla:** İmleci sabit tut, halka dolunca tıklar; ya da başını "evet" diye salla.
- **Sağ tık:** "Hayır" diye salla; ya da `⌃⌥R` ile sonraki beklemeyi sağ tık yap.
- **Kaydır:** `⌃⌥S` ile kaydırma modunu aç, kafanı eğ.
- **Duraklat:** `⌃⌥H`.

### ⌨️ Kısayollar

| Kısayol | İş |
| :--- | :--- |
| `⌃⌥H` | Duraklat / devam |
| `⌃⌥C` | Merkeze al |
| `⌃⌥D` | Dwell tıklamayı aç / kapa (askıdaysa devam ettirir) |
| `⌃⌥S` | Kaydırma modu |
| `⌃⌥R` / `⌃⌥F` / `⌃⌥G` | Sonraki bekleme sağ tık / çift tık / sürükle |
| `⌃⌥,` | Ayarlar |
| `⇧` basılı | İmleç yavaşlar (hassas mod) |

---

## 🎚️ Ayar İpuçları

- **Başını daha az oynatmak istiyorsan:** **İmleç → Hız (piksel / derece)** değerini artır.
- **İmleç kayıyor ya da kendiliğinden tıklıyorsa:** **Sakin kalma filtresini** Orta ya da Yüksek yap, kayma düzeltmeyi açık tut, dwell süresini uzat.
- **Çok küçük hareketler algılanmıyorsa:** Sakin kalma filtresini ve ölü bölgeyi düşür.
- **Kazara jest çok oluyorsa:** **Jestler** sekmesinde hassasiyeti düşür.

---

## 🩺 Sorun Giderme

| Sorun | Çözüm |
| :--- | :--- |
| İzin açık olduğu halde "Erişilebilirlik izni gerekli" | Listeden HeadMouse'u **−** ile sil, `tccutil reset Accessibility com.muhittinefecanturk.headmouse` çalıştır, uygulamayı yeniden aç ve tekrar izin ver |
| "AirPods bekleniyor" | Kulakta, bağlı ve ses çıkışı olarak seçili olmalı |
| Hiçbir şey hareket etmiyor | **Genel** sekmesinde iki izni de kontrol et |
| İmleç ters gidiyor | **İmleç → Yön** |
| Kendiliğinden duruyor ("gerçek fare kullanılıyor") | **Güvenlik** sekmesinde o seçeneği kapat ya da trackpad'e dokunma |
| Sağa/sola yatırma ters | **Jestler → Sağ/sol yönünü ters çevir** |

---

## 🔒 Gizlilik

- HeadMouse'ta **ağ kodu yoktur**; hiçbir veri toplamaz ve göndermez.
- Kafa hareketi verisi Mac'inin belleğinde işlenir, hiçbir yere kaydedilmez.
- Sadece ayarların macOS kullanıcı varsayılanlarında (`UserDefaults`) saklanır.

---

## 🗺️ Durum ve Yol Haritası

Erken sürüm (**0.2**). Tek bir kurulumda geliştirildi ve kullanıldı; pürüzler olabilir, bir şey ters giderse lütfen issue aç.

- [ ] Kalibrasyon sihirbazı
- [ ] Jest algılayıcı için birim testleri
- [ ] Ayarları dışa / içe aktarma
- [ ] Yatay kaydırma
- [ ] Hazır, noter onaylı (notarized) sürüm

---

## 🙏 Teşekkür

[PodsControlMac](https://github.com/sumionochi/PodsControlMac) ve MacPaw'ın [kulaklıkla kafa işaretleme](https://research.macpaw.com/publications/headphones-accessibility) araştırmasından ilham alındı. HeadMouse bağımsız bir projedir ve Apple ile bağlantılı değildir.

---

## 👤 Geliştirici

**Muhittin Efecan Türk**  
*Full Stack & iOS/macOS Developer*  
- **GitHub:** [@muhittinefecanturk](https://github.com/muhittinefecan-turk)

---

## 📄 Lisans

Bu proje **MIT Lisansı** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
