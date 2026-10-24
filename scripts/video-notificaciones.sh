#!/bin/zsh
# Graba el aviso local real de prueba, sin tocar los demás videos de la presentación.
# Antes: compilar con scripts/sim.sh y activar «Recibir avisos» en el simulador.
# Uso: SIM=<UDID> scripts/video-notificaciones.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${SIM:-686013BC-2285-4D46-945B-0D023E1C0C28}"
APP="cl.jpmeniconi.efectodomino"
CRUDO="$(mktemp -d)"
grabador=""
limpiar() {
  if [[ -n "$grabador" ]]; then
    kill -INT "$grabador" 2>/dev/null || true
    wait "$grabador" 2>/dev/null || true
  fi
  rm -rf "$CRUDO"
}
trap limpiar EXIT
xcrun simctl status_bar "$SIM" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl terminate "$SIM" "$APP" 2>/dev/null || true
xcrun simctl launch "$SIM" "$APP" -sinBienvenida YES -abrir notificaciones -avisoDePrueba YES >/dev/null
sleep 0.9
xcrun simctl io "$SIM" recordVideo --codec=h264 --force "$CRUDO/aviso.mp4" >/dev/null 2>&1 &
grabador=$!
sleep 17
kill -INT "$grabador"
wait "$grabador" 2>/dev/null || true
grabador=""
swift scripts/recortar.swift "$CRUDO/aviso.mp4" "$CRUDO/aviso-720.mp4" 0.2
swift scripts/unir.swift presentacion/medios/demo-notificaciones.mp4 "$CRUDO/aviso-720.mp4"
