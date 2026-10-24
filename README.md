# Dominó

**Hacer espacio para moverte: un plan que se adapta a tu semana y un avance que sigue contigo.**

App nativa para iPhone que lleva al plan de movimiento de Camila algo que ya sabe hacer en su trabajo: planificar proyectos con una carta Gantt.
Hackatón Señales de Makana · Caso 01: Camila · 23 y 24 de octubre de 2026.

## El problema que decidimos atacar

Camila tiene 34 años, dirige proyectos en una constructora y quiere volver a sentirse bien en su cuerpo. Se inscribió al gimnasio y fue seis veces: ya tiene una historia de movimiento. Entre reuniones que se alargan y una semana que cambia, le cuesta darle continuidad, y retomar después de una pausa le pesa. El tiempo, la energía y cómo vive el regreso influyen a la vez; la ficha no permite decir que una sola causa explica todo.

Atacamos **cómo retoma**: que, cuando la semana cambia, siempre tenga un próximo paso posible y lo que ya hizo no se pierda. En su trabajo acomoda etapas cuando algo se atrasa; Dominó lleva esa forma de planificar a su plan de movimiento.

## Por qué ese y no otro

- En el megaestudio de Milkman et al. (2021, 61.293 socios), el programa con mayor aumento de asistencia incluía pequeñas recompensas por **volver después de una sesión no realizada**.
- En nuevos socios de gimnasio, la consistencia, la simplicidad y el disfrute se asociaron con formar el hábito (Kaushal y Rhodes, 2015): pasos simples y repetibles.
- La mensualidad no motiva por sí sola (DellaVigna y Malmendier, 2006): no nos apoyamos en la culpa por el pago.
- Son pistas para diseñar, no prueba de nuestro efecto: por eso proponemos medirlo (abajo).

## Qué construimos

- **Un plan que se adapta.** Su semana como carta Gantt, que esquiva su trabajo: una semana de ejemplo o un calendario de prueba, «Camila · Dominó», leído en el iPhone. Si un bloque se cae, Camila escribe qué pasó: un modelo de lenguaje en el iPhone (Foundation Models de Apple) identifica la barrera y un planificador con reglas propone opciones con su efecto en la meta estimada:
  - **holgura**: cabe en la misma semana y nada más cambia;
  - **bloque puente**: corto, pero cuenta completo;
  - **efecto dominó**: los bloques siguientes se corren un espacio, sin acumular más bloques por semana.

  Nada cambia sin su confirmación y lo último se puede deshacer.
- **Un avance que no baja.** Cada sesión hecha deja una **ficha en pie** y sus seis visitas de enero ya cuentan. Su nivel sube cada 7 fichas y 11 logros reconocen volver, usar la holgura o un bloque puente; nada baja ni vence. Cada ficha puede guardar una foto.
- **Modo juego.** 28 días con Javiera, amiga ficticia: una ficha por día como máximo, así que gana quien se mueve más días y no quien entrena más fuerte. Javiera ve cuántas fichas puso, nunca qué días.
- **Preparar y registrar.** Listas antes de salir y después de cada bloque. Camila puede activar avisos locales para preparar su bloque, registrar su experiencia, reconocer lo hecho o revisar su próxima semana, con descanso y un máximo de dos al día. Para invitar a alguien, la app escribe el día y la hora y abre la hoja de compartir de iOS. Cada día, un dato de un estudio publicado con su fuente.
- **Lo que le funciona.** Con sus registros ve qué horarios se cumplen, qué disfruta y qué la ayuda a ir. Al terminar las 6 semanas le queda un manual con sus horarios y tres reglas para seguir sin la app.

## Qué dejamos fuera y por qué

- **Avisos insistentes o activados por defecto:** Camila decide si recibe avisos, cuáles y con qué anticipación; el descanso y la frecuencia se respetan.
- **Rachas y contadores que vuelven a cero:** retomar ya le pesa. Por eso nada baja y un día sin ficha no aparece como falta.
- **Avisar a otros cuando no va:** compartir es decisión de ella, y lo que comparte no muestra faltas.
- **Rutinas, nutrición, wearables, cuentas y servidor:** límites de esta versión, enfocada en la continuidad. Por eso la partida con Javiera corre solo en el iPhone.
- **Su calendario personal y cualquier dato real:** el concurso exige datos ficticios.

## Cómo sabríamos si funciona

En un piloto con grupo de comparación: tiempo de regreso entre una pausa y la siguiente sesión, frecuencia semanal de la semana 1 a la 6 y permanencia en la semana 12.

## Cómo probarlo

Requisitos: Xcode 27 (iOS 26 o superior) y [XcodeGen](https://github.com/yonaskolb/XcodeGen). `scripts/sim.sh` la abre en el simulador y `scripts/iphone.sh` la instala en un iPhone por cable. El reloj de arriba salta a los momentos de la ficha.

Sin un Mac a mano: [el recorrido completo en video](presentacion/medios/recorrido.mp4). La presentación del pitch está en [`presentacion/`](presentacion/).

---

Camila, Javiera, sus fotos y todos sus datos son ficticios. La lectura corre en el dispositivo; si el modelo no está disponible, se usa una lectura local por palabras clave. Construido durante el evento con asistentes de programación con IA; las ilustraciones (con ChatGPT Images) y las fotos ficticias son imágenes generadas ([cómo](scripts/ilustraciones.md)).
