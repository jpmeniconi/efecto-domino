#!/bin/zsh
# Compila, instala y abre Dominó en el simulador.
# Uso: scripts/sim.sh            (iPhone 18 Pro, iOS 27)
#      SIM=<UDID> scripts/sim.sh (otro simulador)
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${SIM:-F721A73D-5E56-4904-936E-691F5715A348}"
BUNDLE="cl.jpmeniconi.efectodomino"

xcodegen generate --quiet
xcodebuild -project EfectoDomino.xcodeproj -scheme EfectoDomino -configuration Debug \
  -destination "id=$SIM" -derivedDataPath build/DerivedData build -quiet

xcrun simctl boot "$SIM" 2>/dev/null || true
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app 2>/dev/null || open -a Simulator 2>/dev/null || true
xcrun simctl install "$SIM" build/DerivedData/Build/Products/Debug-iphonesimulator/EfectoDomino.app
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$SIM" "$BUNDLE"
