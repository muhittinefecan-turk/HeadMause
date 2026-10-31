#!/bin/bash
# HeadMouse'u Xcode olmadan derler: sadece Command Line Tools yeterli.
#   xcode-select --install
# Kullanım:  ./build.sh            (derler ve build/HeadMouse.app üretir)
#            ./build.sh install    (ayrıca /Applications'a kopyalar)
# Kendi sertifikanla imzalamak istersen (izinler yeniden derlemede sıfırlanmaz):
#            SIGN_ID="Apple Development: Adın (XXXX)" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/HeadMouse.app"
ARCH="$(uname -m)"
SIGN_ID="${SIGN_ID:--}"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc bulunamadı. Önce şunu çalıştır:  xcode-select --install" >&2
    exit 1
fi

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Derleniyor ($ARCH, macOS 14+)…"
swiftc -O -swift-version 5 \
    -target "${ARCH}-apple-macos14.0" \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/HeadMouse" \
    -framework Cocoa \
    -framework CoreMotion \
    -framework ApplicationServices \
    -framework Carbon \
    -framework ServiceManagement \
    -framework SwiftUI

cp Info.plist "$APP/Contents/Info.plist"

echo "→ İmzalanıyor…"
BUNDLE_ID="com.muhittinefecanturk.headmouse"
if [ "$SIGN_ID" = "-" ]; then
    # Geçici (ad-hoc) imza her derlemede değişir ve macOS Erişilebilirlik iznini eski
    # derlemeye bağlı tutar. Sabit bir "designated requirement" verince izin, imza
    # yerine bundle kimliğine bağlanır ve yeniden derlemede kaybolmaz.
    codesign --force --deep --sign - \
        --identifier "$BUNDLE_ID" \
        --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP"
else
    codesign --force --deep --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP"
fi
codesign -dr - "$APP" 2>&1 | grep -i designated || true

echo "✓ Hazır: $APP"

if [ "${1:-}" = "install" ]; then
    pkill -x HeadMouse 2>/dev/null || true
    rm -rf /Applications/HeadMouse.app
    cp -R "$APP" /Applications/HeadMouse.app
    echo "✓ /Applications/HeadMouse.app kuruldu"
    open /Applications/HeadMouse.app
else
    echo "Çalıştırmak için:  open $APP"
fi
