# Efecto Dominó · instrucciones para agentes

Hackatón Señales de Makana · Santiago, 23 y 24 de octubre de 2026 · Caso 01: Camila. Equipo de una persona: JP Meniconi.

## Reglas del concurso que afectan el trabajo

- Todo el código se escribe durante el evento, en este repo. Nada traído de antes.
- Solo datos ficticios. Prohibido cargar datos personales reales, incluidos los de JP.
- Entrega: sábado 24 de octubre a las 13:00 en punto. Cuenta el último commit de `main` a esa hora.
- Repo público con un README de una página: qué problema atacamos, por qué ese y qué dejamos fuera.
- Pitch de 5 minutos con demo en vivo y 3 de preguntas. Criterios con igual peso: problema, solución y convicción.

## Producto

App nativa para iPhone (SwiftUI, iOS 26+) que trata el regreso de Camila al ejercicio como una obra con carta Gantt.

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
- Atajos de depuración (solo Debug, ver `App/Depuracion.swift`):
  `xcrun simctl launch <sim> cl.jpmeniconi.efectodomino -reiniciar YES -momento 1 -abrir ajustar -texto "..." -aplicar 0 -foco gantt`
- `Modelo/`: datos, escenario ficticio y `Planificador` (determinístico).
- `IA/Lector.swift`: Foundation Models en el dispositivo clasifica la barrera. `LectorLocal` es el respaldo.
- Codex trabaja en paralelo en contenido (`content-drafts/`, ignorado por git). No tocar sus archivos.
- Commits pequeños y verificados, con push frecuente: el panel del evento cuenta los pushes.

## Estilo de interfaz

- Nunca mayúsculas sostenidas: oraciones normales, también en encabezados de listas (`.textCase(nil)`).
- Sin etiquetas de IA ("IA en el iPhone") ni íconos de destellos.
- Componentes nativos de iOS 26 (Liquid Glass), tipografía del sistema y un solo acento naranja.
- Español de Chile, cálido y concreto. Sin frases motivacionales ni culpa.
- Vocabulario de la interfaz: Mi plan, Tu avance, Meta estimada, fichas en pie, bloque, bloque puente, holgura, programa y muro. Evitar jerga de obra (obra gruesa, recepción, fundaciones, partida, supuesto, ladrillo).
