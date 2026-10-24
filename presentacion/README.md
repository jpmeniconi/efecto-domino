# Presentación del pitch

Once diapositivas de Dominó en HTML, CSS y JS, sin dependencias ni compilación. Usan la tipografía del sistema (SF en Mac) y no necesitan internet. En una pantalla horizontal es una presentación 16:9; en un celular vertical se lee como página. Lo que dice JP en cada diapositiva, los toques de la demo y las preguntas probables están en [`guion.md`](guion.md).

## Verla en local

Abre `index.html` con doble clic, en Safari o Chrome. Funciona como archivo local, sin servidor ni wifi.

Si prefieres un servidor local:

```sh
cd presentacion
python3 -m http.server 8000   # y abre http://localhost:8000
```

| Tecla | Qué hace |
|---|---|
| → · espacio · clic · PageDown | Siguiente |
| ← · PageUp | Anterior |
| F | Pantalla completa |
| 1 · 2 · 3 · 4 | En la diapositiva 6: videos de respaldo de la demo |
| B | Pantalla negra |
| T | Tema claro u oscuro |
| ? | Todas las teclas |

El número de la diapositiva queda en la dirección: `index.html#6` abre la demo.

## Publicarla en Vercel

1. En vercel.com: **Add New… → Project** e importa `jpmeniconi/efecto-domino`.
2. **Root Directory:** `presentacion`.
3. **Framework Preset:** Other. Deja vacíos el Build Command y el Output Directory: no hay nada que compilar.
4. **Deploy.** Cada push a `main` la vuelve a publicar.

`vercel.json` fija el preset Other. `.vercelignore` deja fuera de la publicación este README, el guion y la herramienta del QR.

## Capturas y videos

Van en `medios/` con estos nombres. Mientras falte alguno, su iPhone muestra el nombre del archivo esperado.

| Archivo | Qué muestra | Dónde aparece |
|---|---|---|
| `bienvenida.png` | La bienvenida | 1 · Portada |
| `mi-plan.png` | Mi plan, lunes 19:05 | Respaldo del lunes |
| `ajustar.png` | Ajustar con «Se alargó la reunión» y sus opciones | Respaldo del lunes, si falta el video |
| `ajustar-miercoles.png` | Ajustar con «Ya perdí la semana» y sus opciones | Respaldo del miércoles, si falta el video |
| `efecto-domino.png` | La carta Gantt después del ajuste del miércoles | Respaldo del miércoles |
| `meta-estimada.png` | La meta corrida 2 días y el «Ajuste al plan» | Respaldo del miércoles, si falta el video |
| `programa.png` | El programa completo | Respaldo del programa |
| `domingo.png` | La semana para confirmar | Respaldo del domingo |
| `tu-avance.png` | Tu avance con Tu nivel | 7 · Y además |
| `foto-ampliada.png` | La foto de una ficha, con día y hora | 7 · Y además |
| `modo-juego.png` | El Modo juego con Javiera y «Es tu turno» | 7 · Y además |
| `tu-avance-abajo.png` | Tus fotos, el Modo juego y «¿Sabías que?» en Tu avance | 7 · Y además |
| `fotos.png`, `registrar-foto.png`, `registrar.png`, `modo-juego-tablero.png` | El carrusel de fotos, agregar una foto, registrar un bloque y el tablero del Modo juego | No aparecen; quedan de referencia |
| `calendario.png` | El plan con el calendario «Camila · Dominó» | 8 · Su semana real |
| `calendario-escenario.png` | El escenario de demo con el calendario conectado | No aparece; queda de referencia |
| `lo-que-te-funciona.png` | «Lo que te funciona» | 9 · Cuando termina el programa |
| `manual.png` | El manual al terminar las 6 semanas | 9 · Cuando termina el programa |
| `demo-lunes.mp4` | La demo del lunes | Respaldo del lunes (tecla 1) |
| `demo-miercoles.mp4` | La demo del miércoles | Respaldo del miércoles (tecla 2) |
| `demo-programa.mp4` | El programa completo | Respaldo del programa (tecla 4) |

Capturas PNG del simulador iPhone 18 Pro, 1206 × 2622, verticales. Videos MP4 H.264, verticales y sin audio; bajo 20 MB cada uno cargan rápido también desde Vercel. Si un video no está, se muestran sus capturas lado a lado.

## PDF de respaldo

En Chrome, con la presentación en horizontal: **Imprimir → Guardar como PDF**, márgenes «Ninguno» y gráficos de fondo activados. Sale una diapositiva por página, en 16:9.

## QR

`qr-repo.svg` lleva a `https://github.com/jpmeniconi/efecto-domino`. Se genera sin servicios externos con `python3 presentacion/herramientas/qr.py`, que solo usa la biblioteca estándar.
