// Portada: rotación de ejemplos de apertura, sin avanzar la app ni la presentación.
// Citas exactas de EfectoDomino/Bienvenida/FrasesDeInicio.swift.
(function () {
  'use strict';
  var demo = document.getElementById('inicio-demo');
  if (!demo) return;
  var portada = demo.closest('.diapositiva');
  var figura = demo.closest('figure');
  var texto = document.getElementById('inicio-frase');
  var autor = document.getElementById('inicio-autor');
  var caption = document.getElementById('inicio-caption');
  var reducir = window.matchMedia('(prefers-reduced-motion: reduce)');
  var citas = [
    { id: 'cita_042', texto: 'Empieza, entonces, por las cosas pequeñas.', autor: 'Epicteto' },
    { id: 'cita_063', texto: 'Debes llevar tu propio ritmo.', autor: 'Robert Louis Stevenson' },
    { id: 'cita_005', texto: 'La creación de mil bosques está en una bellota.', autor: 'Ralph Waldo Emerson' }
  ];
  var indice = 0;
  var visible = false;
  var imprimiendo = false;
  var transcurrido = 0;
  var carga = 0;
  var previo = null;
  var raf = null;

  function activa() {
    var enDeck = document.documentElement.classList.contains('modo-deck');
    return !document.hidden && !imprimiendo && visible && portada.classList.contains('activa') &&
      (!enDeck || portada.classList.contains('actual'));
  }

  function mostrar(animar) {
    var cita = citas[indice];
    texto.textContent = cita.texto;
    autor.textContent = cita.autor;
    demo.dataset.cita = cita.id;
    var bloque = texto.parentElement;
    bloque.getAnimations().forEach(function (animacion) { animacion.cancel(); });
    if (animar && !reducir.matches && activa()) {
      bloque.animate([{ opacity: 0, transform: 'translateY(7px)' }, { opacity: 1, transform: 'translateY(0)' }],
        { duration: 450, easing: 'cubic-bezier(.2,.7,.2,1)' });
    }
  }

  function preparar(valor) {
    var progreso = Math.min(1, valor / 2400);
    demo.style.setProperty('--inicio-carga', String(100 * Math.pow(1 - progreso, 2)));
    var listo = progreso === 1;
    demo.dataset.listo = String(listo);
    caption.textContent = listo ? 'Listo cuando tú quieras' : 'Preparando tu plan…';
  }

  function cuadro(ahora) {
    raf = null;
    if (!activa() || reducir.matches) { previo = null; return; }
    var delta = previo === null ? 0 : Math.min(100, ahora - previo);
    previo = ahora;
    carga = Math.min(2400, carga + delta);
    preparar(carga);
    transcurrido += delta;
    if (transcurrido >= 5000) {
      transcurrido = 0;
      indice = (indice + 1) % citas.length;
      mostrar(true);
    }
    raf = requestAnimationFrame(cuadro);
  }

  function actualizar() {
    if (reducir.matches) { carga = 2400; preparar(carga); }
    if (activa() && !reducir.matches) {
      if (raf === null) { previo = null; raf = requestAnimationFrame(cuadro); }
    } else {
      if (raf !== null) cancelAnimationFrame(raf);
      raf = null;
      previo = null;
      texto.parentElement.getAnimations().forEach(function (animacion) { animacion.finish(); });
    }
  }

  figura.addEventListener('click', function (e) { e.stopPropagation(); });

  new IntersectionObserver(function (entradas) {
    visible = entradas[0].isIntersecting && entradas[0].intersectionRatio >= .2;
    actualizar();
  }, { threshold: [0, .2] }).observe(demo);
  new MutationObserver(actualizar).observe(portada, { attributes: true, attributeFilter: ['class'] });
  new MutationObserver(actualizar).observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
  document.addEventListener('visibilitychange', actualizar);
  if (reducir.addEventListener) reducir.addEventListener('change', actualizar);
  else reducir.addListener(actualizar);
  window.addEventListener('beforeprint', function () { imprimiendo = true; actualizar(); });
  window.addEventListener('afterprint', function () { imprimiendo = false; actualizar(); });
  mostrar(false);
  preparar(carga);
  actualizar();
})();
