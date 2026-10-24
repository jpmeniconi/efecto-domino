#!/bin/zsh
# Graba los videos de respaldo de la demo en el simulador, sin toques: los atajos de depuración
# (-ritmo, -lecturaLocal) escriben y eligen a velocidad humana. Quedan en presentacion/medios/.
# Uso: scripts/sim.sh y después scripts/videos.sh   (o SIM=<UDID> para otro simulador)
set -uo pipefail
cd "$(dirname "$0")/.."
SIM="${SIM:-F721A73D-5E56-4904-936E-691F5715A348}"
APP="cl.jpmeniconi.efectodomino"
CRUDO="$(mktemp -d)"
DESTINO="presentacion/medios"

xcrun simctl status_bar "$SIM" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

# grabar <nombre> <segundos antes de grabar> <segundos de grabación> <argumentos de la app…>
grabar() {
  local nombre=$1 antes=$2 dura=$3; shift 3
  xcrun simctl terminate "$SIM" "$APP" 2>/dev/null
  sleep 0.8
  xcrun simctl launch "$SIM" "$APP" "$@" >/dev/null
  sleep "$antes"
  xcrun simctl io "$SIM" recordVideo --codec=h264 --force "$CRUDO/$nombre.mp4" >/dev/null 2>&1 &
  local pid=$!
  sleep "$dura"
  kill -INT $pid
  wait $pid 2>/dev/null
}

grabar demo-lunes 0.9 13 -reiniciar YES -momento 0 -abrir ajustar -texto "Se alargó la reunión" -aplicar 0 -foco gantt -ritmo YES -lecturaLocal YES
grabar demo-miercoles 0.9 14 -reiniciar YES -momento 1 -abrir ajustar -texto "Ya perdí la semana" -aplicar 2 -foco gantt -ritmo YES -lecturaLocal YES
grabar demo-programa 1.2 7 -momento 1 -abrir programa -zoom dos -luego todo

# Los primeros cuadros de una grabación salen en blanco: se recortan y se bajan a 720 de ancho.
swift scripts/recortar.swift "$CRUDO/demo-lunes.mp4" "$DESTINO/demo-lunes.mp4" 1.45
swift scripts/recortar.swift "$CRUDO/demo-miercoles.mp4" "$DESTINO/demo-miercoles.mp4" 1.0
swift scripts/recortar.swift "$CRUDO/demo-programa.mp4" "$DESTINO/demo-programa.mp4" 0.5
