// Dominó · presentación del pitch: navegación, número en el hash, medios y respaldo de la demo.
// Sin dependencias ni compilación: funciona abierta como archivo local y publicada en Vercel.
(function () {
  'use strict';

  var raiz = document.documentElement;
  var deck = document.getElementById('deck');
  var diapositivas = Array.prototype.slice.call(document.querySelectorAll('.diapositiva'));
  var total = diapositivas.length;
  var anuncio = document.getElementById('anuncio');
  var negro = document.getElementById('negro');
  var ayuda = document.getElementById('ayuda');
  var vertical = window.matchMedia('(orientation: portrait)');
  var actual = -1;
  var salidas = [];
  var imprimiendo = false;

  function enDeck() { return raiz.classList.contains('modo-deck'); }
  function limitar(n) { return Math.min(Math.max(n, 0), total - 1); }

  /** «#4» → 3. Sin número, la primera. */
  function desdeHash() {
    var n = parseInt(location.hash.slice(1), 10);
    return isFinite(n) ? limitar(n - 1) : 0;
  }

  function fijarHash(indice) {
    var hash = '#' + (indice + 1);
    if (location.hash === hash) return;
    try { history.replaceState(null, '', hash); } catch { location.hash = hash; }
  }

  // ------------------------------------------------------------------ Navegación

  /** Muestra una diapositiva. Sus elementos entran en el cuadro siguiente para que la transición corra. */
  function ir(indice) {
    indice = limitar(indice);
    cerrarRespaldo();
    if (indice === actual) return;
    var previa = actual;
    actual = indice;
    fijarHash(indice);
    if (!enDeck()) return;

    diapositivas.forEach(function (d, i) {
      var esta = i === indice;
      d.classList.toggle('actual', esta);
      d.inert = !esta;
      d.setAttribute('aria-hidden', esta ? 'false' : 'true');
    });

    var entrante = diapositivas[indice];
    clearTimeout(salidas[indice]);
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        if (diapositivas[actual] === entrante) entrante.classList.add('activa');
      });
    });

    // La que sale conserva su estado hasta terminar el fundido; después queda lista para volver a entrar.
    if (previa >= 0) {
      var saliente = diapositivas[previa];
      clearTimeout(salidas[previa]);
      salidas[previa] = setTimeout(function () {
        if (diapositivas[actual] !== saliente) saliente.classList.remove('activa');
      }, 420);
    }

    anuncio.textContent = (indice + 1) + ' de ' + total + ': ' + entrante.getAttribute('data-titulo');
  }

  function siguiente() { ir(actual + 1); }
  function anterior() { ir(actual - 1); }

  // ------------------------------------------------------------------ Modo: presentación o página vertical

  var observador = null;
  var visibles = new Map();

  if ('IntersectionObserver' in window) {
    observador = new IntersectionObserver(function (entradas) {
      if (enDeck()) return;
      entradas.forEach(function (entrada) {
        visibles.set(entrada.target, entrada.intersectionRatio);
        if (entrada.isIntersecting && entrada.intersectionRatio >= 0.2) entrada.target.classList.add('activa');
      });
      // El hash sigue a la diapositiva que más se ve.
      var mejor = -1;
      var mayor = 0;
      diapositivas.forEach(function (d, i) {
        var r = visibles.get(d) || 0;
        if (r > mayor) { mayor = r; mejor = i; }
      });
      if (mejor >= 0 && mejor !== actual) { actual = mejor; fijarHash(mejor); }
    }, { threshold: [0, 0.2, 0.4, 0.6, 0.8, 1] });
  }

  function aplicarModo() {
    if (imprimiendo) return;
    raiz.classList.toggle('modo-pagina', vertical.matches);
    raiz.classList.toggle('modo-deck', !vertical.matches);
    raiz.style.setProperty('--escala', Math.min(window.innerWidth / 1920, window.innerHeight / 1080));
    cerrarRespaldo();
    var indice = actual >= 0 ? actual : desdeHash();

    if (enDeck()) {
      if (observador) observador.disconnect();
      diapositivas.forEach(function (d) { d.classList.remove('activa', 'actual'); });
      actual = -1;
      ir(indice);
      return;
    }

    diapositivas.forEach(function (d) {
      d.classList.remove('actual');
      d.inert = false;
      d.removeAttribute('aria-hidden');
    });
    if (observador) {
      observador.disconnect();
      visibles.clear();
      diapositivas.forEach(function (d) { observador.observe(d); });
    } else {
      diapositivas.forEach(function (d) { d.classList.add('activa'); });
    }
    actual = indice;
    if (indice > 0) diapositivas[indice].scrollIntoView();
  }

  if (vertical.addEventListener) vertical.addEventListener('change', aplicarModo);
  else if (vertical.addListener) vertical.addListener(aplicarModo);

  // ------------------------------------------------------------------ Teclado, clic y gestos

  document.addEventListener('keydown', function (e) {
    if (e.defaultPrevented || e.metaKey || e.ctrlKey || e.altKey) return;
    var t = e.target;
    if (t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName))) return;
    var tecla = e.key;

    if (!negro.hidden) {
      negro.hidden = true;
      if (tecla === 'b' || tecla === 'B' || tecla === '.' || tecla === 'Escape') { e.preventDefault(); return; }
    }

    if (!ayuda.hidden) {
      cerrarAyuda();
      if (tecla === 'Escape' || tecla === '?' || tecla === 'h' || tecla === 'H') { e.preventDefault(); return; }
    }

    if (respaldoAbierto()) {
      if (tecla === ' ' || tecla === 'Spacebar' || tecla === 'k' || tecla === 'K') { e.preventDefault(); alternarVideo(); return; }
      if (tecla === 'Escape') { e.preventDefault(); cerrarRespaldo(true); return; }
    }

    if (/^[1-4]$/.test(tecla) && diapositivas[actual] && diapositivas[actual].contains(respaldo)) {
      e.preventDefault();
      abrirClip(tecla);
      return;
    }

    switch (tecla) {
      case 'f': case 'F': case 'F5':
        e.preventDefault();
        pantallaCompleta();
        return;
      case 'b': case 'B': case '.':
        e.preventDefault();
        negro.hidden = false;
        return;
      case 't': case 'T':
        e.preventDefault();
        alternarTema();
        return;
      case '?': case 'h': case 'H':
        e.preventDefault();
        abrirAyuda();
        return;
    }

    // En la página vertical, flechas y espacio desplazan como siempre.
    if (!enDeck()) return;
    switch (tecla) {
      case 'ArrowRight': case 'ArrowDown': case 'PageDown': case 'Right': case 'Down':
        e.preventDefault(); siguiente(); break;
      case ' ': case 'Spacebar':
        e.preventDefault(); if (e.shiftKey) anterior(); else siguiente(); break;
      case 'ArrowLeft': case 'ArrowUp': case 'PageUp': case 'Left': case 'Up':
        e.preventDefault(); anterior(); break;
      case 'Home':
        e.preventDefault(); ir(0); break;
      case 'End':
        e.preventDefault(); ir(total - 1); break;
    }
  });

  // Clic en cualquier parte avanza, salvo en enlaces, botones, el respaldo o una capa abierta.
  document.addEventListener('click', function (e) {
    if (!enDeck() || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    if (e.target.closest('a, button, video, input, select, textarea, [role="dialog"], .capa')) return;
    var seleccion = window.getSelection ? String(window.getSelection()) : '';
    if (seleccion) return;
    siguiente();
  });

  negro.addEventListener('click', function () { negro.hidden = true; });
  ayuda.addEventListener('click', function (e) { if (!e.target.closest('.ayuda-tarjeta')) cerrarAyuda(); });

  // Deslizar con el dedo en una tableta horizontal.
  var toque = null;
  deck.addEventListener('touchstart', function (e) {
    toque = e.touches.length === 1 ? { x: e.touches[0].clientX, y: e.touches[0].clientY } : null;
  }, { passive: true });
  deck.addEventListener('touchend', function (e) {
    if (!toque || !enDeck() || respaldoAbierto()) { toque = null; return; }
    var dx = e.changedTouches[0].clientX - toque.x;
    var dy = e.changedTouches[0].clientY - toque.y;
    toque = null;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) { if (dx < 0) siguiente(); else anterior(); }
  }, { passive: true });

  window.addEventListener('hashchange', function () {
    var indice = desdeHash();
    if (enDeck()) ir(indice);
    else actual = indice;
  });

  // El cursor se esconde quieto, como en Keynote.
  var reposo = 0;
  function moverCursor() {
    raiz.classList.remove('sin-cursor');
    clearTimeout(reposo);
    reposo = setTimeout(function () { raiz.classList.add('sin-cursor'); }, 2500);
  }
  document.addEventListener('mousemove', moverCursor);
  moverCursor();

  // ------------------------------------------------------------------ Pantalla completa, tema y ayuda

  function pantallaCompleta() {
    var d = document;
    try {
      var promesa;
      if (d.fullscreenElement || d.webkitFullscreenElement) {
        promesa = (d.exitFullscreen || d.webkitExitFullscreen).call(d);
      } else {
        promesa = (raiz.requestFullscreen || raiz.webkitRequestFullscreen).call(raiz);
      }
      if (promesa && promesa.catch) promesa.catch(function () {});
    } catch { /* El navegador no lo permite: queda en ventana. */ }
  }

  function alternarTema() {
    var claro = raiz.getAttribute('data-tema') !== 'claro';
    if (claro) raiz.setAttribute('data-tema', 'claro');
    else raiz.removeAttribute('data-tema');
    var color = document.querySelector('meta[name="theme-color"]');
    if (color) color.setAttribute('content', claro ? '#ffffff' : '#000000');
    try { localStorage.setItem('domino-tema', claro ? 'claro' : 'oscuro'); } catch { /* sin almacenamiento */ }
  }

  var focoAntesDeAyuda = null;
  function abrirAyuda() {
    focoAntesDeAyuda = document.activeElement;
    ayuda.hidden = false;
    ayuda.tabIndex = -1;
    ayuda.focus();
  }
  function cerrarAyuda() {
    ayuda.hidden = true;
    if (focoAntesDeAyuda && focoAntesDeAyuda.focus) focoAntesDeAyuda.focus();
    focoAntesDeAyuda = null;
  }

  // ------------------------------------------------------------------ Capturas en los iPhone

  /** Con la captura cargada se ve la imagen; si falta, el marco muestra el nombre del archivo esperado. */
  function vigilarImagen(telefono) {
    var img = telefono.querySelector('.pantalla img');
    if (!img) return;
    img.addEventListener('load', function () { telefono.classList.add('con-imagen'); });
    img.addEventListener('error', function () { telefono.classList.remove('con-imagen'); });
    if (img.getAttribute('src') && img.complete) telefono.classList.toggle('con-imagen', img.naturalWidth > 0);
  }

  Array.prototype.forEach.call(document.querySelectorAll('.telefono'), vigilarImagen);

  // ------------------------------------------------------------------ Respaldo de la demo

  var respaldo = document.getElementById('respaldo');
  var escena = document.getElementById('respaldo-escena');
  var telefonos = escena.querySelectorAll('.telefono');
  var video = escena.querySelector('video');
  var botonVideo = document.getElementById('boton-video');
  var progreso = document.getElementById('progreso');
  var barra = document.getElementById('progreso-barra');
  var clips = Array.prototype.slice.call(respaldo.querySelectorAll('.clip'));
  var videoEsperado = '';
  var capturasActuales = [];
  var focoAntesDeRespaldo = null;
  var cuadro = 0;

  function respaldoAbierto() { return !respaldo.hidden; }

  /** Pone una captura en un iPhone del respaldo; sin captura, el marco dice qué archivo falta. */
  function ponerCaptura(telefono, archivo, titulo, esperados) {
    var img = telefono.querySelector('img');
    telefono.classList.remove('con-imagen', 'con-video');
    telefono.querySelector('.falta-titulo').textContent = titulo;
    telefono.querySelector('.falta code').textContent = esperados.map(function (a) { return 'medios/' + a; }).join('\n');
    if (archivo) img.setAttribute('src', 'medios/' + archivo);
    else img.removeAttribute('src');
    if (archivo && img.complete) telefono.classList.toggle('con-imagen', img.naturalWidth > 0);
  }

  function abrirClip(numero) {
    var boton = respaldo.querySelector('.clip[data-clip="' + numero + '"]');
    if (!boton) return;
    if (!respaldoAbierto()) {
      focoAntesDeRespaldo = document.activeElement;
      respaldo.hidden = false;
      raiz.classList.add('con-respaldo');
      respaldo.tabIndex = -1;
      respaldo.focus({ preventScroll: true });
    }
    clips.forEach(function (c) { c.setAttribute('aria-current', c === boton ? 'true' : 'false'); });

    var titulo = boton.querySelector('.clip-nombre').textContent;
    var archivoVideo = boton.getAttribute('data-video') || '';
    capturasActuales = (boton.getAttribute('data-capturas') || '').split(/\s+/).filter(Boolean);

    Array.prototype.forEach.call(telefonos, function (telefono, i) {
      var esperados = capturasActuales.slice(i, i + 1);
      if (i === 0 && archivoVideo) esperados.unshift(archivoVideo);
      ponerCaptura(telefono, capturasActuales[i], titulo, esperados);
    });
    // Sin video, las capturas lado a lado. Con video, solo cuando el video no está.
    mostrarCapturas(archivoVideo ? 1 : capturasActuales.length);

    video.pause();
    mostrarControles(false);
    videoEsperado = archivoVideo ? 'medios/' + archivoVideo : '';
    if (videoEsperado) {
      video.setAttribute('src', videoEsperado);
      video.load();
    } else {
      video.removeAttribute('src');
      video.load();
    }
  }

  function cerrarRespaldo(devolverFoco) {
    if (!respaldo || respaldo.hidden) return;
    video.pause();
    respaldo.hidden = true;
    raiz.classList.remove('con-respaldo');
    cancelAnimationFrame(cuadro);
    if (devolverFoco && focoAntesDeRespaldo && focoAntesDeRespaldo.focus) focoAntesDeRespaldo.focus({ preventScroll: true });
    focoAntesDeRespaldo = null;
  }

  function videoListo() { return telefonos[0].classList.contains('con-video'); }

  function mostrarCapturas(cantidad) {
    escena.setAttribute('data-visibles', String(Math.min(Math.max(cantidad, 1), telefonos.length)));
  }

  function mostrarControles(mostrar) {
    botonVideo.hidden = !mostrar;
    progreso.hidden = !mostrar;
    barra.style.transform = 'scaleX(0)';
    if (mostrar) pintarEstado();
  }

  function alternarVideo() {
    if (!videoListo()) return;
    if (video.paused || video.ended) {
      if (video.ended) video.currentTime = 0;
      var promesa = video.play();
      if (promesa && promesa.catch) promesa.catch(function () {});
    } else {
      video.pause();
    }
  }

  function pintarEstado() {
    var pausado = video.paused || video.ended;
    botonVideo.setAttribute('data-estado', pausado ? 'pausado' : 'reproduciendo');
    botonVideo.querySelector('.boton-video-texto').textContent = video.ended ? 'Repetir' : pausado ? 'Reproducir' : 'Pausa';
  }

  function pintarProgreso() {
    var fraccion = video.duration ? video.currentTime / video.duration : 0;
    barra.style.transform = 'scaleX(' + Math.min(Math.max(fraccion, 0), 1) + ')';
    if (!video.paused && !video.ended) cuadro = requestAnimationFrame(pintarProgreso);
  }

  video.addEventListener('loadeddata', function () {
    if (video.getAttribute('src') !== videoEsperado) return;
    telefonos[0].classList.add('con-video');
    mostrarCapturas(1);
    mostrarControles(true);
    var promesa = video.play();
    if (promesa && promesa.catch) promesa.catch(function () { pintarEstado(); });
  });

  video.addEventListener('error', function () {
    if (!videoEsperado || video.getAttribute('src') !== videoEsperado) return;
    telefonos[0].classList.remove('con-video');
    mostrarControles(false);
    mostrarCapturas(capturasActuales.length);
  });

  video.addEventListener('play', function () { pintarEstado(); cancelAnimationFrame(cuadro); cuadro = requestAnimationFrame(pintarProgreso); });
  video.addEventListener('pause', pintarEstado);
  video.addEventListener('ended', function () { pintarEstado(); pintarProgreso(); });

  botonVideo.addEventListener('click', function (e) {
    alternarVideo();
    if (e.detail > 0) respaldo.focus({ preventScroll: true });
  });
  telefonos[0].addEventListener('click', alternarVideo);
  document.getElementById('respaldo-cerrar').addEventListener('click', function () { cerrarRespaldo(true); });

  Array.prototype.forEach.call(document.querySelectorAll('.momento, .clip'), function (boton) {
    boton.addEventListener('click', function (e) {
      abrirClip(boton.getAttribute('data-clip'));
      // Con el mouse, el foco no se queda en el botón: así el espacio pausa el video y no lo reinicia.
      if (e.detail > 0) respaldo.focus({ preventScroll: true });
    });
  });

  // Las capturas del respaldo se cargan de antemano para que aparezcan al tiro.
  window.addEventListener('load', function () {
    clips.forEach(function (c) {
      (c.getAttribute('data-capturas') || '').split(/\s+/).filter(Boolean).forEach(function (archivo) {
        var img = new Image();
        img.src = 'medios/' + archivo;
      });
    });
  });

  // ------------------------------------------------------------------ Imprimir

  // El PDF siempre sale en 16:9, una diapositiva por página y con cada diagrama terminado.
  // Al imprimir, el navegador mide la orientación del papel: mientras dure, no se cambia de modo.
  window.addEventListener('beforeprint', function () {
    imprimiendo = true;
    cerrarRespaldo();
    raiz.classList.add('imprimiendo', 'modo-deck');
    raiz.classList.remove('modo-pagina');
    diapositivas.forEach(function (d) { d.classList.add('activa'); });
  });
  window.addEventListener('afterprint', function () {
    imprimiendo = false;
    raiz.classList.remove('imprimiendo');
    actual = desdeHash();
    aplicarModo();
  });

  // ------------------------------------------------------------------ Partida

  aplicarModo();
})();

// Lámina 6: vista previa local de una invitación; no abre ni envía mensajes.
(function () {
  'use strict';
  var boton = document.getElementById('semana-invitar');
  var mensaje = document.getElementById('semana-mensaje');
  if (!boton || !mensaje) return;

  boton.addEventListener('keydown', function (e) {
    // Deja que Enter y espacio activen el botón nativo, sin avanzar la presentación.
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') e.stopPropagation();
  });
  boton.closest('.semana-invitacion').addEventListener('click', function (e) {
    e.stopPropagation();
  });
  boton.addEventListener('click', function () {
    boton.setAttribute('aria-expanded', 'true');
    mensaje.hidden = false;
    // Repite la entrada sin ocultar el mensaje ni cambiar el nombre de la acción.
    // Con Reducir movimiento, el CSS no crea ninguna animación.
    mensaje.getAnimations().forEach(function (animacion) {
      animacion.currentTime = 0;
      animacion.play();
    });
  });
})();
