(function () {
  'use strict';
  var lamina = document.getElementById('12');
  var video = document.getElementById('video-avisos');
  var boton = document.getElementById('avisos-reproducir');
  var estado = document.getElementById('aviso-estado');
  if (!lamina || !video || !boton) return;
  [boton, video, lamina.querySelector('.avisos-controles a')].forEach(function (control) {
    control.addEventListener('keydown', function (evento) {
      if (evento.key === ' ' || evento.key === 'Enter') evento.stopPropagation();
    });
  });

  function pintar() {
    var reproduciendo = !video.paused && !video.ended;
    boton.textContent = reproduciendo ? 'Pausar el aviso' : video.ended ? 'Volver a ver el aviso' : 'Ver cómo llega un aviso';
    boton.setAttribute('aria-pressed', String(reproduciendo));
  }
  boton.addEventListener('click', function () {
    if (!video.paused && !video.ended) { video.pause(); return; }
    if (video.ended) video.currentTime = 0;
    var promesa = video.play();
    if (promesa) promesa.catch(function () {
      estado.textContent = 'No se pudo reproducir el video. Puedes usar los controles del iPhone de esta lámina.';
    });
  });
  ['play', 'pause', 'ended'].forEach(function (evento) { video.addEventListener(evento, pintar); });
  video.addEventListener('error', function () {
    estado.textContent = 'El video no está disponible. La imagen muestra cómo llega el aviso de prueba.';
  });
  new MutationObserver(function () {
    if (document.documentElement.classList.contains('modo-deck') && !lamina.classList.contains('actual')) video.pause();
  }).observe(lamina, { attributes: true, attributeFilter: ['class'] });
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (entradas) {
      if (!entradas[0].isIntersecting) video.pause();
    }).observe(lamina);
  }
  document.addEventListener('visibilitychange', function () { if (document.hidden) video.pause(); });
})();
