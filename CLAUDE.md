# Dominó · instrucciones para agentes

Hackatón Señales de Makana · Santiago, 23 y 24 de octubre de 2026 · Caso 01: Camila. Equipo de una persona: JP Meniconi.

## Reglas del concurso que afectan el trabajo

- Todo el código se escribe durante el evento, en este repo. Nada traído de antes.
- Solo datos ficticios. Prohibido cargar datos personales reales, incluidos los de JP.
- Entrega: sábado 24 de octubre a las 13:00 en punto. Cuenta el último commit de `main` a esa hora.
- Repo público con un README de una página: qué problema atacamos, por qué ese y qué dejamos fuera.
- Pitch de 5 minutos con demo en vivo y 3 de preguntas. Criterios con igual peso: problema, solución y convicción.

## Producto

App nativa para iPhone (SwiftUI, iOS 26+) que trata el regreso de Camila al ejercicio como una obra con carta Gantt.

Se llamó «Efecto Dominó» hasta la tarde del 23 de octubre. El target, las carpetas, el repo y el bundle (`cl.jpmeniconi.efectodomino`) conservan ese nombre a propósito: cambiar el bundle instalaría otra app en el iPhone y perdería su estado.

- Un bloque que se cae primero se absorbe en la **holgura** de la semana. Si no cabe, los siguientes se corren un espacio (**efecto dominó**) y se mueve la fecha estimada de la meta.
- **Frecuencia antes que intensidad:** cuatro bloques por semana, dos de ellos cortos (Kaushal y Rhodes, 2015).
- **Fichas en pie:** cada bloque hecho deja una ficha; una falta no bota ninguna. Volver después de un atraso deja una **ficha de regreso** (Milkman et al., 2021).
- Las seis visitas de enero ya cuentan: Camila no parte de cero.
- No se usa la culpa por la mensualidad (DellaVigna y Malmendier, 2006).

## Reglas del planificador (no romper)

- Nunca acumular deuda: cada semana tiene como máximo `porSemana` bloques del patrón.
- Lo hecho no se mueve ni se borra.
- Un cambio se aplica solo cuando Camila lo confirma.
- Aceptar un plan no es entrenar: solo "Fui" pone un ladrillo.
- No exponer faltas a terceros. Compartir es decisión de Camila.
- Sin consejos médicos. Ante dolor, sugerir un profesional.
- La IA solo interpreta lo que escribe Camila. Los horarios los decide el `Planificador`.

## Cómo se trabaja

- `project.yml` (XcodeGen) genera `EfectoDomino.xcodeproj`. Después de crear archivos: `xcodegen generate`.
- `scripts/sim.sh` compila, instala y abre la app en el simulador (iPhone 18 Pro, iOS 27). En Xcode 27 el simulador vive en DeviceHub.
- La app tiene tres pestañas (`Vistas/PestanasView.swift`): Mi plan, Programa y Tu avance. Los controles del escenario de demo (el reloj y el menú de arriba en Mi plan) no son una pestaña: son para la demo, no para Camila.
- Atajos de depuración (solo Debug, ver `App/Depuracion.swift`):
  `xcrun simctl launch <sim> cl.jpmeniconi.efectodomino -reiniciar YES -momento 1 -abrir ajustar -texto "..." -aplicar 0 -foco gantt`
  - `-pestana plan|programa|avance` abre la app en esa pestaña. `-abrir programa` lleva a Programa y `-abrir aprendizajes` a Tu avance con «Lo que te funciona» abierto. Cada atajo corre una sola vez: volver a una pestaña no repite el ajuste ni la hoja.
  - `-abrir aprendizajes -ejemplo YES` abre «Lo que te funciona» con el ejemplo de la semana 6 y `-foco alterminar` baja al manual (`-ejemplo` vive en `Vistas/AprendizajesView.swift`).
  - `-crearCalendarioDePrueba YES` crea en el simulador un calendario «Camila · Dominó» de prueba y `-conectarCalendario YES` lo conecta (`NO` vuelve a la semana de ejemplo). En el simulador, dar antes el permiso: `xcrun simctl privacy <sim> grant calendar cl.jpmeniconi.efectodomino`.
  - `-ritmo YES` escribe y elige en «Ajustar» a velocidad humana y `-lecturaLocal YES` usa solo la lectura local: con ellos `scripts/videos.sh` graba los videos de respaldo de la demo en `presentacion/medios/`.
  - `-sinBienvenida YES` salta la frase de inicio. En el programa (`-abrir programa`): `-zoom semana|dos|todo|<días>`, `-luego <zoom>` (lo cambia a los dos segundos, como un toque), `-detalle <n>` abre el bloque n en orden de fecha, `-accion fui|ajustar` sigue desde ese detalle y `-detente grande` lo abre expandido. En el detalle, `-seccion origen|registro|trabajo` baja a esa sección.
  - En Tu avance (`-pestana avance`): `-foco logros` baja al nivel y los logros, y con él `-logro <clave>` abre el globo de ese logro (claves en `Logro.Clave`, `Vistas/Logros.swift`). `-verFotos YES` baja a «Tus fotos» y `-fotoAmpliada <n>` abre la foto de la ficha n a pantalla completa. `-juego YES` abre el Modo juego, `-juegoModo record` parte en «Contra tu récord» y `-juegoFoco tablero|reglas` baja a esa tarjeta.
  - En «Fui» (`-abrir registrar`): `-fotoDePrueba <foto>` deja elegida una foto ficticia de Camila (por ejemplo `foto-mat`; con `-registrar YES` se guarda sola) y `-elegirFoto YES` abre la grilla de fotos.
  - `-abrir notificaciones` abre las preferencias de avisos. También están en Mi plan → … → Notificaciones. Solo «Recibir avisos» solicita permiso; «Probar un aviso» muestra una prueba en cinco segundos. Con el permiso ya concedido en el simulador, `-avisoDePrueba YES` dispara esa prueba para `scripts/video-notificaciones.sh`.
- `Modelo/PlanDeAvisos.swift` calcula los avisos locales con el reloj real del teléfono, sin cambiar el reloj de demo. `App/Notificaciones.swift` los sincroniza al guardar y al volver a la app: descanso, dos avisos diarios como máximo (incluidos los ya programados que vencieron hoy), cancelación al mover/registrar/deshacer y reconocimiento solo después de «Fui». Las preferencias y las reservas viven en UserDefaults; no se cambió el formato de `obra.json`.
- `Modelo/`: datos, escenario ficticio y `Planificador` (determinístico).
- `IA/Lector.swift`: Foundation Models en el dispositivo clasifica la barrera. `LectorLocal` es el respaldo.
- Codex trabaja en paralelo en contenido (`content-drafts/`, ignorado por git). No tocar sus archivos.
- Varias sesiones de Claude Code trabajan en paralelo, cada una en su worktree. Antes de integrar, probar o cambiar el trabajo de otra, buscar en claude-mem qué hizo y qué pidió JP (skill `mem-search`: `search`, luego `timeline` y `get_observations`). Lo que no aparezca ahí se pregunta antes de suponerlo.
- Commits pequeños y verificados, con push frecuente: el panel del evento cuenta los pushes.

## Estilo de interfaz

- Nunca mayúsculas sostenidas: oraciones normales, también en encabezados de listas (`.textCase(nil)`).
- Sin etiquetas de IA ("IA en el iPhone") ni íconos de destellos.
- Componentes nativos de iOS 26 (Liquid Glass), tipografía del sistema y un solo acento naranja.
- Español de Chile, cálido y concreto. Sin frases motivacionales ni culpa.
- Vocabulario de la interfaz: Mi plan, Tu avance, Meta estimada, fichas en pie, bloque, bloque puente, holgura, programa, muro y trabajo (no «pega»). Evitar jerga de obra (obra gruesa, recepción, fundaciones, partida, supuesto, ladrillo).
