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
swift scripts/recortar.swift "$CRUDO/demo-lunes.mp4" "$CRUDO/demo-lunes-720.mp4" 1.45
swift scripts/recortar.swift "$CRUDO/demo-miercoles.mp4" "$CRUDO/demo-miercoles-720.mp4" 1.0
swift scripts/recortar.swift "$CRUDO/demo-programa.mp4" "$CRUDO/demo-programa-720.mp4" 0.5
# El arranque cambia entre tomas: estos clips también quitan el blanco que quede.
for clip in demo-lunes demo-miercoles demo-programa; do
  swift scripts/unir.swift "$DESTINO/$clip.mp4" "$CRUDO/$clip-720.mp4"
done

# ── Videos del recorrido completo ─────────────────────────────────────────────────────────────────
# El estado se guarda entre lanzamientos, así que el orden importa: -reiniciar parte de cero, y el
# calentamiento deja «Tu avance» con 6 fichas vistas para que la ficha 7 (la de «Fui») anime el nivel nuevo.
# La app tarda entre 1 y 3 s en mostrar algo después de abrirse. recortar.swift corta antes de que aparezca y
# unir.swift quita el blanco que quede; «toma.mp4@1.0» parte 1 s después de que aparece el contenido.

# Como grabar, pero con el video corriendo antes de abrir la app: se ve desde el primer cuadro cómo carga.
grabarDesdeCero() {
  local nombre=$1 antes=$2 dura=$3; shift 3
  xcrun simctl terminate "$SIM" "$APP" 2>/dev/null
  sleep 0.8
  xcrun simctl io "$SIM" recordVideo --codec=h264 --force "$CRUDO/$nombre.mp4" >/dev/null 2>&1 &
  local pid=$!
  sleep "$antes"
  xcrun simctl launch "$SIM" "$APP" "$@" >/dev/null
  sleep "$dura"
  kill -INT $pid
  wait $pid 2>/dev/null
}

grabarDesdeCero demo-bienvenida 2 9.5
grabar demo-detalle 0.9 7 -reiniciar YES -momento 0 -abrir programa -detalle 1 -detente grande
grabar demo-domingo 0.9 6.8 -reiniciar YES -momento 3
# Calentamiento sin grabar: Tu avance con 6 fichas (el nivel anima solo cuando llegan fichas nuevas).
xcrun simctl terminate "$SIM" "$APP" 2>/dev/null
sleep 0.8
xcrun simctl launch "$SIM" "$APP" -reiniciar YES -momento 0 -pestana avance >/dev/null
sleep 5
# «Fui» en dos tomas que se unen: con -registrar la hoja se guarda sola al segundo de abrirse y apenas se alcanza a ver,
# así que la primera toma deja la hoja abierta (ilustración y foto elegida) y la segunda parte con la hoja ya abierta
# (0,8 s después de que aparece el contenido): se cierra, se guarda y sale el aviso.
grabar registrar-abre 0.9 5 -reiniciar YES -momento 0 -abrir registrar -fotoDePrueba foto-parque
grabar registrar-guarda 0.9 6 -reiniciar YES -momento 0 -abrir registrar -fotoDePrueba foto-parque -registrar YES
# Tu avance en tres tomas que se unen: el nivel que sube, los logros y la foto nueva.
grabar tu-avance-nivel 0.9 4.8 -momento 0 -pestana avance
grabar tu-avance-logros 0.9 5 -momento 0 -pestana avance -foco logros
grabar tu-avance-fotos 0.9 4.8 -momento 0 -pestana avance -verFotos YES
grabar demo-fotos 0.9 5.5 -momento 0 -pestana avance -fotoAmpliada 7
grabar demo-modo-juego 0.9 6.8 -momento 0 -pestana avance -juego YES
grabar demo-modo-juego-tablero 0.9 6.8 -momento 0 -pestana avance -juego YES -juegoFoco tablero
grabar demo-aprendizajes 0.9 6.8 -abrir aprendizajes -ejemplo YES -foco alterminar

# nombre:desde. La bienvenida parte con la pantalla de inicio antes de abrir la app, por eso corta más tarde.
for toma in demo-bienvenida:2.8 demo-detalle:0.5 demo-domingo:0.5 registrar-abre:0.5 registrar-guarda:0.5 \
            tu-avance-nivel:0.5 tu-avance-logros:0.5 tu-avance-fotos:0.5 \
            demo-fotos:0.5 demo-modo-juego:0.5 demo-modo-juego-tablero:0.5 demo-aprendizajes:0.5; do
  swift scripts/recortar.swift "$CRUDO/${toma%%:*}.mp4" "$CRUDO/${toma%%:*}-720.mp4" "${toma##*:}"
done
# nombre:segundos que se saltan después de que aparece el contenido (lo que entra con fundido parte casi vacío).
for clip in demo-bienvenida:0.3 demo-detalle:0 demo-domingo:0.1 demo-fotos:0 demo-modo-juego:0.1 demo-modo-juego-tablero:0.1 demo-aprendizajes:0.1; do
  swift scripts/unir.swift "$DESTINO/${clip%%:*}.mp4" "$CRUDO/${clip%%:*}-720.mp4@${clip##*:}"
done

# demo-registrar y demo-tu-avance: las tomas en una. recorrido: todos los videos en el orden de la presentación.
swift scripts/unir.swift "$DESTINO/demo-registrar.mp4" "$CRUDO/registrar-abre-720.mp4" "$CRUDO/registrar-guarda-720.mp4@0.8"
swift scripts/unir.swift "$DESTINO/demo-tu-avance.mp4" "$CRUDO/tu-avance-nivel-720.mp4" "$CRUDO/tu-avance-logros-720.mp4@1.0" "$CRUDO/tu-avance-fotos-720.mp4@1.0"
swift scripts/unir.swift "$DESTINO/recorrido.mp4" \
  "$DESTINO/demo-bienvenida.mp4" "$DESTINO/demo-lunes.mp4" "$DESTINO/demo-miercoles.mp4" "$DESTINO/demo-programa.mp4" \
  "$DESTINO/demo-detalle.mp4" "$DESTINO/demo-domingo.mp4" "$DESTINO/demo-registrar.mp4" "$DESTINO/demo-tu-avance.mp4" \
  "$DESTINO/demo-fotos.mp4" "$DESTINO/demo-modo-juego.mp4" "$DESTINO/demo-modo-juego-tablero.mp4" "$DESTINO/demo-aprendizajes.mp4"
