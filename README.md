# Efecto Dominó

**Camila no necesita otra rutina: necesita que una falta no tumbe la obra.**

App nativa para iPhone que trata el regreso al ejercicio como lo que Camila hace todos los días en la pega: gestionar una obra.
Hackatón Señales de Makana · Caso 01: Camila · 23 y 24 de octubre de 2026.

## El problema que decidimos atacar

Camila no abandona por falta de tiempo ni de ganas: dejó de ir incluso en semanas tranquilas. Lo que la tumba es lo que pasa **después de faltar**: siente que el proyecto se cayó y que tiene que partir de cero («mañana parto», «el lunes»). Cada reinicio es más grande que el anterior y la culpa la aleja más.

Como jefa de proyectos, en sus obras nunca demuele lo construido porque una partida se atrasó: usa la holgura, reprograma y revisa el supuesto de rendimiento. Con su cuerpo aplica la regla contraria. Ese es el problema que atacamos: **cómo vuelve después de faltar**.

## Por qué ese y no otro

- En el megaestudio de Milkman et al. (2021, 61.293 socios), la intervención más efectiva premiaba **volver después de faltar**.
- El hábito se forma con la **frecuencia de las primeras semanas**, no con la intensidad (Kaushal y Rhodes, 2015), y el abandono se juega en las primeras 12 (Sperandei et al., 2016).
- La mensualidad no motiva por sí sola (DellaVigna y Malmendier, 2006): no nos apoyamos en la culpa por el pago.
- Rutinas, recordatorios, rachas y frases motivacionales ya los probó o la ficha los descarta.

## Qué construimos

- **Carta Gantt viva** con su semana de pega (ficticia): los martes y jueves llega tarde.
- **Ajustar un bloque.** Camila escribe qué pasó. Un modelo de lenguaje que corre en el iPhone (Foundation Models de Apple) identifica la barrera y un planificador con reglas propone opciones, cada una con su efecto en la fecha estimada de su meta:
  - **holgura**: el bloque cabe en la misma semana y no se mueve nada;
  - **bloque puente**: corto, pero cuenta completo;
  - **efecto dominó**: los bloques siguientes se corren un espacio. Nunca se acumula deuda.

  Nada cambia sin su confirmación y todo se puede deshacer.
- **Su avance nunca baja.** Sus seis visitas de enero ya cuentan. Cada bloque hecho deja una **ficha en pie**: en el efecto dominó una ficha bota a las demás; aquí una falta no bota ninguna. Volver después de un atraso deja una **ficha de regreso**.
- **Ajuste al plan.** Si el miércoles 06:30 no le funciona, la app propone pasarlo a la tarde: se cambia el horario, no a ella.
- **Domingo en la noche.** En vez de «mañana parto», su semana concreta para confirmar en un toque.
- **Checklists** antes de salir (bolso, agenda bloqueada) y después (qué ayudó, dejar listo el próximo).

## Qué dejamos fuera y por qué

- **Recordatorios y correos:** ya silenció las notificaciones, y los recordatorios funcionan solo mientras duran.
- **Rachas y contadores que vuelven a cero:** el día que falla, la culpa la saca de nuevo.
- **Avisar a su círculo cuando falta:** exponer faltas genera vergüenza y evasión. Compartir avances será siempre decisión de ella.
- **Rutinas, nutrición, wearables, cuentas y servidor:** no son su problema y no caben en dos días.
- **Su calendario real:** el concurso exige datos ficticios.

## Cómo sabríamos si funciona

Lo mediríamos en vez de suponerlo: tiempo de regreso después de faltar, frecuencia semanal en las semanas 1 a 6 y permanencia en la semana 12, comparando con un grupo de control.

## Cómo probarlo

Requisitos: Xcode 27 (iOS 26 o superior) y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
scripts/sim.sh      # compila y abre en el simulador
scripts/iphone.sh   # instala en un iPhone conectado por cable
```

Toca el reloj de arriba para saltar a los momentos de la ficha: lunes 19:05, miércoles 06:45, miércoles 20:15 y domingo 23:55.

---

Camila y todos sus datos son ficticios. La lectura corre en el dispositivo; si el modelo no está disponible, se usa una lectura local por palabras clave. Construido durante el evento con asistentes de programación con IA.
