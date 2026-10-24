# Presentación del pitch

Once diapositivas del pitch y una lámina final de apoyo de Dominó en HTML, CSS y JavaScript, sin dependencias ni compilación. El relato es: **Camila quiere sentirse bien → encuentra espacio → elige un paso posible → lo hace → ve su avance → descubre qué le funciona**.

La tipografía es la del sistema (SF en Mac). En horizontal se usa un lienzo 1920 × 1080 escalado, con proporción 16:9; en un celular vertical se lee como página. El texto para presentar, el recorrido del iPhone y las preguntas probables están en [`guion.md`](guion.md). El presupuesto suma 5:00; la meta de ensayo es 4:30–4:40.

## Verla en local

Abre `index.html` con doble clic en Safari o Chrome. Funciona como archivo local con los medios de esta carpeta, sin servidor ni wifi.

También puedes servir la carpeta:

```sh
cd presentacion
python3 -m http.server 8000
```

Abre `http://localhost:8000`.

| Tecla | Qué hace |
|---|---|
| → · espacio · clic · PageDown | Siguiente lámina |
| ← · PageUp | Anterior |
| F | Pantalla completa |
| 1 · 2 · 3 · 4 | En la lámina 7: ajuste, registro, avance y programa |
| Espacio, con respaldo abierto | Pausa o continúa el video |
| Esc | Cierra el respaldo o la ayuda |
| B | Pantalla negra |
| T | Tema claro u oscuro |
| ? | Ayuda |

El número de la lámina queda en la dirección: `index.html#7` abre la demo. En Vercel es `https://efecto-domino-presentacion.vercel.app/#7`.

## Orden y comportamiento

| # | Lámina | Qué aporta |
|---|---|---|
| 1 | Dominó · Hacer espacio para moverte | Propósito y bienvenida con citas de autores |
| 2 | Quiere volver a sentirse bien | Aspiración y contexto |
| 3 | Una forma de planificar que ya conoce | Metáfora de la carta Gantt y progreso conservado |
| 4 | Qué ayuda a sostener el movimiento | Decisiones informadas por evidencia, sin promesas universales |
| 5 | Un plan que se adapta contigo | Holgura, bloque puente, reprogramación y confirmación |
| 6 | Su plan encaja en su semana | Calendario e invitación a alguien cercano |
| 7 | Demo · Un paso posible. Un avance real | Ajustar → confirmar → registrar → ver avance |
| 8 | Su avance se hace visible | Fichas/nivel, una foto y ciclos del Modo juego |
| 9 | Descubrir qué le funciona | Horarios, ayudas y manual para seguir |
| 10 | Qué dejamos fuera | Avisos insistentes, rachas que vuelven a cero, exposición de faltas y límites de esta versión |
| 11 | ¿Camila vuelve y lo sostiene? | Métricas propuestas para un piloto y cierre |
| 12 | Apoyo: avisos opcionales | Grabación real de una notificación; fuera de los cinco minutos del pitch |

En la portada, tres citas de autores se alternan cada cinco segundos dentro del iPhone. No hay botones ni contador; con Reducir movimiento se mantiene una frase estática. Es un comportamiento de la presentación. La bienvenida de la app nativa mantiene su frase hasta que la persona toca la flecha habilitada: no entra sola al terminar la carga.

La lámina 8 incorpora «Tu progreso, ciclo a ciclo»: periodos de 28 días del Modo juego, una ficha por día y comparación con el propio récord. Son distintos del programa de seis semanas; el historial de sesiones permanece.

En la lámina 6, **Invitar a alguien** muestra una vista previa animada y repetir el toque repite la animación. La presentación no envía mensajes. En la app nativa, la invitación usa la hoja para compartir de iOS.

## Publicación en Vercel

El sitio está en `https://efecto-domino-presentacion.vercel.app/` y el proyecto usa la carpeta `presentacion` del repositorio `jpmeniconi/efecto-domino`.

Configuración del proyecto:

- **Root Directory:** `presentacion`.
- **Framework Preset:** Other.
- **Build Command / Output Directory:** sin compilación ni directorio adicional.
- La integración con Git publica los cambios de `main`.

`vercel.json` conserva la configuración del sitio. `.vercelignore` excluye de la publicación este README, el guion y la herramienta del QR. Antes de publicar, verifica la presentación local y los respaldos; después comprueba la versión desplegada.

## Capturas y videos

Los medios están en `medios/`. Los cuatro respaldos de la lámina 7 son:

| Tecla | Video | Captura de respaldo | Función |
|---|---|---|---|
| 1 | `demo-lunes.mp4` | `mi-plan.png`, `ajustar.png` | Adaptar: ajustar un bloque |
| 2 | `demo-registrar.mp4` | `registrar.png` | Registrar: guardar una sesión |
| 3 | `demo-tu-avance.mp4` | `tu-avance.png` | Reconocer: ver el avance |
| 4 | `demo-programa.mp4` | `programa.png` | Ver el programa completo |

Si un video no carga, su respaldo usa las capturas disponibles. Los videos demuestran esas funciones; no tienen por qué reproducir las mismas fechas, cifras o decisiones del iPhone durante el pitch.

Medios visibles en las otras láminas:

| Archivo | Uso |
|---|---|
| `bienvenida.png` | Referencia visual de la bienvenida; la portada usa su representación interactiva |
| `calendario.png` | 6 · Su plan encaja en su semana |
| `tu-avance.png` | 8 · Fichas y nivel |
| `foto-ampliada.png` | 8 · Foto de una ficha |
| `lo-que-te-funciona.png`, `manual.png` | 9 · Aprendizajes y manual |

Los demás archivos de `medios/`, incluidos el juego, las fotos, el miércoles y el domingo, quedan disponibles como referencias y recorridos adicionales. `recorrido.mp4` reúne varias funciones y no sustituye el ensayo de dos minutos descrito en el guion.

Las capturas PNG son verticales del simulador iPhone 18 Pro, 1206 × 2622. Los videos son MP4 H.264 verticales y sin audio. Mantén las imágenes dentro del marco de iPhone y revisa la legibilidad tanto a 1920 × 1080 como en vertical.

## Verificación antes de compartir

1. Recorre las once láminas en horizontal y vertical; comprueba texto, imágenes y consola.
2. En la portada, comprueba la rotación automática cada cinco segundos, la ausencia de botones y contador y la frase estática con Reducir movimiento.
3. En la lámina 6, repite la invitación; debe mantener su etiqueta y no avanzar de lámina.
4. Desde `#7`, prueba los cuatro respaldos, pausa y cierre. El registro y el avance deben ocupar las teclas 2 y 3.
5. Comprueba el enlace del QR y que el guion conserve un presupuesto total de 5:00.

## PDF de respaldo

En Chrome, con la presentación en horizontal: **Imprimir → Guardar como PDF**, márgenes **Ninguno** y gráficos de fondo activados. El estilo de impresión usa una lámina por página en 16:9. Revisa la vista previa antes de guardar: el PDF conserva imágenes estáticas, no las interacciones ni los videos.

## QR

`qr-repo.svg` lleva a `https://github.com/jpmeniconi/efecto-domino`. La herramienta local `python3 presentacion/herramientas/qr.py` usa solo la biblioteca estándar y no requiere servicios externos.
