#!/bin/zsh
# Compila, instala y abre Dominó en un iPhone conectado por cable.
# Detecta el iPhone y el equipo de firma solos; se pueden forzar con IPHONE=<UDID> TEAM=<ID>.
set -euo pipefail
cd "$(dirname "$0")/.."
BUNDLE="cl.jpmeniconi.efectodomino"

IPHONE="${IPHONE:-$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /iPhone/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')}"
TEAM="${TEAM:-$(security find-certificate -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p')}"

if [[ -z "$IPHONE" ]]; then echo "No encuentro un iPhone conectado." >&2; exit 1; fi
if [[ -z "$TEAM" ]]; then echo "No encuentro un certificado Apple Development. Agrega tu cuenta en Xcode > Settings > Accounts." >&2; exit 1; fi
echo "iPhone: $IPHONE · equipo: $TEAM"

xcodegen generate --quiet
xcodebuild -project EfectoDomino.xcodeproj -scheme EfectoDomino -configuration Debug \
  -destination "id=$IPHONE" -derivedDataPath build/DerivedData -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic build -quiet

xcrun devicectl device install app --device "$IPHONE" build/DerivedData/Build/Products/Debug-iphoneos/EfectoDomino.app
xcrun devicectl device process launch --device "$IPHONE" "$BUNDLE"
