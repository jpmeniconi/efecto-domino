// Dos escenas reales del mismo estado: invitación (0–4 s), reubicación (4–8 s).
(function () {
  'use strict';
  var telefono = document.getElementById('semana-telefono');
  if (!telefono) return;
  var lamina = telefono.closest('.diapositiva');
  var video = document.getElementById('semana-video');
  var poster = document.getElementById('semana-poster');
  var control = document.getElementById('semana-reproducir');
  var etapa = document.getElementById('semana-etapa');
  var invitar = document.getElementById('semana-invitar');
  var reducir = window.matchMedia('(prefers-reduced-motion: reduce)');
  var visible = false;
  var estabaActiva = false;
  var imprimiendo = false;
  var fallo = false;
  var escena = 1;

  function activa() {
    return visible && !document.hidden && !imprimiendo && lamina.classList.contains('activa') &&
      (!document.documentElement.classList.contains('modo-deck') || lamina.classList.contains('actual'));
  }

  function indicar(numero) {
    escena = numero;
    telefono.dataset.etapa = String(numero);
    etapa.textContent = numero === 1 ? '1 · Invitar' : '2 · Detalle del cambio';
  }

  function imagen(numero) {
    video.pause();
    telefono.classList.remove('con-video');
    indicar(numero);
    poster.src = numero === 1 ? 'medios/semana-invitar.png' : 'medios/semana-reubicacion.png';
    poster.alt = numero === 1 ?
      'Caminata del sábado 24 a las 10:30, con su preparación y el botón Invitar a alguien' :
      'Programa a dos semanas: la flecha une el origen del miércoles 21 con el nuevo bloque del lunes 26';
    control.textContent = fallo ? (numero === 1 ? 'Ver reubicación' : 'Ver invitación') : (numero === 1 ? 'Ver recorrido' : 'Repetir');
  }

  function reproducir(desdeInicio) {
    if (fallo) { imagen(escena === 1 ? 2 : 1); return; }
    if (desdeInicio) { video.currentTime = 0; indicar(1); }
    var promesa = video.play();
    if (promesa && promesa.catch) promesa.catch(function () {
      if (video.paused) { telefono.classList.remove('con-video'); control.textContent = 'Ver recorrido'; }
    });
  }

  function sincronizar() {
    var ahora = activa();
    if (ahora && !estabaActiva) {
      imagen(1);
      if (!reducir.matches && !fallo) reproducir(true);
    } else if (!ahora) {
      video.pause();
    }
    estabaActiva = ahora;
  }

  control.addEventListener('click', function () {
    if (fallo) { imagen(escena === 1 ? 2 : 1); return; }
    if (!video.paused) video.pause();
    else reproducir(!telefono.classList.contains('con-video') || video.ended);
  });
  invitar.addEventListener('click', function () { imagen(1); });
  telefono.addEventListener('click', function (e) { e.stopPropagation(); });
  control.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') e.stopPropagation();
  });
  video.addEventListener('playing', function () {
    if (!activa()) { video.pause(); return; }
    telefono.classList.add('con-video');
    control.textContent = 'Pausar';
  });
  video.addEventListener('pause', function () {
    if (telefono.classList.contains('con-video')) control.textContent = video.ended ? 'Repetir' : 'Continuar';
  });
  video.addEventListener('timeupdate', function () {
    if (telefono.classList.contains('con-video')) indicar(video.currentTime < 4 ? 1 : 2);
  });
  video.addEventListener('ended', function () { imagen(2); });
  video.addEventListener('error', function () { fallo = true; imagen(1); });

  new IntersectionObserver(function (entradas) {
    visible = entradas[0].isIntersecting && entradas[0].intersectionRatio >= .2;
    sincronizar();
  }, { threshold: [0, .2] }).observe(telefono);
  new MutationObserver(sincronizar).observe(lamina, { attributes: true, attributeFilter: ['class'] });
  new MutationObserver(sincronizar).observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
  document.addEventListener('visibilitychange', sincronizar);
  function movimiento() { if (reducir.matches) imagen(1); }
  if (reducir.addEventListener) reducir.addEventListener('change', movimiento);
  else reducir.addListener(movimiento);
  window.addEventListener('beforeprint', function () { imprimiendo = true; sincronizar(); });
  window.addEventListener('afterprint', function () { imprimiendo = false; sincronizar(); });
})();
