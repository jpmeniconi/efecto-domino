import XCTest
@testable import EfectoDomino

final class PlanificadorTests: XCTestCase {

    // MARK: - Semilla

    func testLaSemillaArmaLaMetaSinChoquesNiDeuda() {
        let e = Prueba.semilla()

        XCTAssertEqual(e.bloques.count, e.proyecto.meta)
        XCTAssertTrue(e.bloques.allSatisfy { $0.estado == .planificado })
        let semanas = Dictionary(grouping: e.bloques) { $0.inicio.lunes }
        XCTAssertEqual(semanas.count, e.proyecto.semanas)
        XCTAssertTrue(semanas.values.allSatisfy { $0.count == e.proyecto.porSemana })
        XCTAssertTrue(e.bloques.allSatisfy { Planificador.ventanaDelPatron(e, para: $0) != nil })
        XCTAssertEqual(e.recepcionBase, Prueba.fecha(semana: 5, dia: 6, 10, 30))
        XCTAssertEqual(Planificador.recepcion(e), e.recepcionBase)
        verificarReglas(e)
    }

    func testElPatronSaltaLoQueChocaConElTrabajoSinRecuperarloDespues() {
        var e = Prueba.semilla()
        e.trabajo.append(EventoTrabajo(titulo: "Visita temprana", inicio: Prueba.fecha(dia: 3, 6, 0), fin: Prueba.fecha(dia: 3, 8, 0)))

        let slots = Planificador.slotsDelPatron(e, desde: Prueba.lunes, cantidad: 8)

        XCTAssertEqual(slots.count, 8)
        XCTAssertFalse(slots.contains { $0.fecha.mismoDia(que: Prueba.fecha(dia: 3, 6, 30)) })
        XCTAssertEqual(slots.filter { $0.fecha.lunes == Prueba.lunes }.count, 3, "La semana pierde un espacio, no lo recupera")
        XCTAssertEqual(slots.filter { $0.fecha.lunes == Prueba.lunes.mas(dias: 7) }.count, 4)
        XCTAssertTrue(slots.allSatisfy { !Planificador.choca(e, inicio: $0.fecha, minutos: $0.minutos) })
    }

    // MARK: - Holgura y bloque puente

    func testLaHolguraReubicaEnLaMismaSemanaSinMoverLaMeta() throws {
        let e = Prueba.enMomento(0)
        let bloque = try XCTUnwrap(e.proximo)
        XCTAssertEqual(bloque.inicio, Prueba.fecha(dia: 1, 19, 30))

        let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(.horario))
        let holgura = try XCTUnwrap(propuestas.first)
        XCTAssertEqual(holgura.etiqueta, "Usa la holgura")
        XCTAssertEqual(holgura.impactoDias, 0)
        XCTAssertEqual(holgura.impactoTexto, "Tu meta no se mueve")

        let despues = Planificador.aplicar(holgura.accion, a: e)

        let movido = despues.bloque(bloque.id)
        XCTAssertEqual(movido.inicio, Prueba.fecha(dia: 5, 19, 30), "Un gimnasio se mueve a otro gimnasio de la misma semana")
        XCTAssertEqual(movido.tipo, .gimnasio)
        XCTAssertEqual(movido.origen, bloque.inicio)
        XCTAssertFalse(movido.esPuente)
        XCTAssertEqual(Planificador.recepcion(despues), Planificador.recepcion(e))
        for otro in e.bloques where otro.id != bloque.id {
            XCTAssertEqual(despues.bloque(otro.id), otro)
        }
        verificarReglas(despues)
    }

    func testElBloquePuenteEsCortoYQuedaElMismoDia() throws {
        let e = Prueba.enMomento(1)
        let bloque = try XCTUnwrap(e.proximo)
        XCTAssertEqual(bloque.inicio, Prueba.fecha(dia: 3, 6, 30))

        let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(.reinicio))
        XCTAssertEqual(propuestas.map(\.etiqueta), ["Bloque puente", "Usa la holgura", "Partir el lunes"])

        let puente = propuestas[0]
        let despues = Planificador.aplicar(puente.accion, a: e)

        let movido = despues.bloque(bloque.id)
        XCTAssertEqual(movido.inicio, Prueba.fecha(dia: 3, 19, 30))
        XCTAssertEqual(movido.minutos, 20)
        XCTAssertTrue(movido.esPuente)
        XCTAssertNil(movido.origen, "Si queda el mismo día no deja fantasma en la carta Gantt")
        XCTAssertEqual(puente.impactoDias, 0)
        verificarReglas(despues)
    }

    // MARK: - Efecto dominó

    func testPartirElLunesCorreLosSiguientesUnEspacioYMueveLaMeta() throws {
        let e = Prueba.enMomento(1)
        let bloque = try XCTUnwrap(e.proximo)
        let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(.reinicio))
        let lunes = try XCTUnwrap(propuestas.first { $0.etiqueta == "Partir el lunes" })
        let destino = Prueba.fecha(semana: 1, dia: 1, 19, 30)
        XCTAssertEqual(lunes.accion, .empujar(bloque: bloque.id, fecha: destino))

        let despues = Planificador.aplicar(lunes.accion, a: e)

        // Cada bloque desde ese lunes toma el espacio del siguiente; el último pasa a la semana 7.
        let siguientes = e.bloques.filter { $0.inicio >= destino.inicioDelDia }.sorted { $0.inicio < $1.inicio }
        XCTAssertEqual(siguientes.count, 20)
        XCTAssertEqual(despues.bloque(bloque.id).inicio, destino)
        XCTAssertEqual(despues.bloque(bloque.id).origen, bloque.inicio)
        for (k, otro) in siguientes.dropLast().enumerated() {
            XCTAssertEqual(despues.bloque(otro.id).inicio, siguientes[k + 1].inicio)
        }
        XCTAssertEqual(despues.bloque(siguientes[19].id).inicio, Prueba.fecha(semana: 6, dia: 1, 19, 30))

        // Lo de esta semana antes del lunes no se toca.
        for otro in e.bloques where otro.id != bloque.id && otro.inicio < destino.inicioDelDia {
            XCTAssertEqual(despues.bloque(otro.id), otro)
        }

        // No se suma ningún bloque para recuperar: se corre la meta.
        XCTAssertEqual(despues.bloques.count, e.bloques.count)
        let base = try XCTUnwrap(Planificador.recepcion(e))
        let nueva = try XCTUnwrap(Planificador.recepcion(despues))
        XCTAssertEqual(base.dias(hasta: nueva), 2)
        XCTAssertEqual(lunes.impactoDias, 2)
        XCTAssertEqual(lunes.impactoTexto, "Tu meta se corre 2 días")
        verificarReglas(despues)
    }

    func testSiElCalendarioBloqueaEseLunesLaPropuestaDiceElDiaReal() throws {
        var e = Prueba.enMomento(1)
        e.trabajo.append(EventoTrabajo(
            titulo: "Turno de noche",
            inicio: Prueba.fecha(semana: 1, dia: 1, 18, 0),
            fin: Prueba.fecha(semana: 1, dia: 1, 23, 0)
        ))
        let bloque = try XCTUnwrap(e.proximo)
        let partir = try XCTUnwrap(
            Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(.reinicio)).first {
                if case .empujar = $0.accion { true } else { false }
            }
        )
        XCTAssertEqual(partir.accion, .empujar(bloque: bloque.id, fecha: Prueba.fecha(semana: 1, dia: 2, 21, 15)))
        XCTAssertEqual(partir.etiqueta, "Partir el martes")
        XCTAssertEqual(partir.titulo, "Martes 27 · 21:15")
        XCTAssertEqual(partir.confirmacion, "Partimos el martes. Tu avance sigue contando.")
    }

    func testVariosEmpujonesSeguidosNuncaAcumulanDeuda() throws {
        var e = Prueba.enMomento(1)
        var meta = try XCTUnwrap(Planificador.recepcion(e))
        for semana in 1...3 {
            let bloque = try XCTUnwrap(e.proximo)
            let lunes = try XCTUnwrap(
                Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(.reinicio)).first { $0.etiqueta == "Partir el lunes" }
            )
            e = Planificador.aplicar(lunes.accion, a: e)
            e.ahora = Prueba.fecha(semana: semana, dia: 1, 19, 5)

            let nueva = try XCTUnwrap(Planificador.recepcion(e))
            XCTAssertGreaterThan(nueva, meta)
            meta = nueva
            XCTAssertEqual(e.bloques.count, e.proyecto.meta)
            verificarReglas(e, "empujón \(semana)")
        }
    }

    func testPartirElLunesNoSeOfreceSiElBloqueYaEsElLunes() throws {
        let e = Prueba.enMomento(3)
        let bloque = try XCTUnwrap(e.proximo)
        XCTAssertEqual(bloque.inicio, Prueba.fecha(semana: 1, dia: 1, 19, 30))

        for barrera in TipoBarrera.allCases {
            let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(barrera))
            XCTAssertFalse(propuestas.contains { $0.etiqueta == "Partir el lunes" }, "\(barrera): mover el bloque a donde ya está")
            verificarPropuestas(propuestas, de: bloque, en: e, "domingo · \(barrera)")
        }
    }

    // MARK: - Pausa

    func testPausarCorreLoQueVieneSinPerderLoHecho() throws {
        var e = Prueba.enMomento(1)
        let lunesHecho = try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 1, 19, 30)))
        e.marcarHecho(lunesHecho.id)

        let pausas = Planificador.pausas(e)
        XCTAssertEqual(pausas.map(\.titulo), ["Hasta el lunes 26", "Hasta el lunes 2"])
        let hasta = Prueba.fecha(semana: 1, dia: 1, 0, 0)
        XCTAssertEqual(pausas[0].accion, .pausar(hasta: hasta))

        let despues = Planificador.aplicar(pausas[0].accion, a: e)

        XCTAssertEqual(despues.pausaHasta, hasta)
        XCTAssertEqual(despues.bloques.count, e.bloques.count)
        XCTAssertEqual(despues.bloque(lunesHecho.id), e.bloque(lunesHecho.id))
        for antes in e.bloques where antes.estado == .planificado && antes.inicio >= e.ahora.inicioDelDia {
            XCTAssertGreaterThanOrEqual(despues.bloque(antes.id).inicio, hasta)
        }
        let base = try XCTUnwrap(Planificador.recepcion(e))
        let nueva = try XCTUnwrap(Planificador.recepcion(despues))
        XCTAssertEqual(pausas[0].impactoDias, base.dias(hasta: nueva))
        verificarPausa(pausas[0], en: e, "miércoles")
    }

    func testUnaSegundaPausaNuncaAdelantaElPlan() {
        let e = Prueba.enMomento(1)
        let enPausa = Planificador.aplicar(Planificador.pausas(e)[1].accion, a: e)

        for pausa in Planificador.pausas(enPausa) {
            verificarPausa(pausa, en: enPausa, "en pausa · \(pausa.titulo)")
        }
    }

    func testElDomingoLaPausaNoEsUnaPausaVacia() {
        let e = Prueba.enMomento(3)
        for pausa in Planificador.pausas(e) {
            verificarPausa(pausa, en: e, "domingo · \(pausa.titulo)")
        }
    }

    // MARK: - Lo hecho

    func testLoHechoNuncaSeMueve() throws {
        var e = Prueba.enMomento(1)
        for fecha in [Prueba.fecha(dia: 1, 19, 30), Prueba.fecha(dia: 2, 21, 15)] {
            e.marcarHecho(try XCTUnwrap(e.bloque(en: fecha)).id)
        }
        let hechos = e.hechos
        let bloque = try XCTUnwrap(e.proximo)

        var cambios: [(String, EstadoObra)] = []
        for barrera in TipoBarrera.allCases {
            for propuesta in Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(barrera)) {
                cambios.append(("\(barrera) · \(propuesta.etiqueta)", Planificador.aplicar(propuesta.accion, a: e)))
            }
        }
        for pausa in Planificador.pausas(e) {
            cambios.append((pausa.titulo, Planificador.aplicar(pausa.accion, a: e)))
        }
        var conMovida = e
        conMovida.movidasPorVentana["3-06:30"] = 1
        let ajuste = try XCTUnwrap(Planificador.ajusteDeRendimiento(conMovida))
        cambios.append(("ajuste al plan", Planificador.cambiarPatron(conMovida, ajuste: ajuste)))

        // Ni siquiera pidiéndolo directo.
        let viernes = Slot(fecha: Prueba.fecha(dia: 5, 19, 30), tipo: .gimnasio, minutos: 45)
        cambios.append(("reubicar lo hecho", Planificador.reubicar(e, id: hechos[0].id, slot: viernes, puente: false)))
        cambios.append(("empujar lo hecho", Planificador.empujar(e, id: hechos[0].id, a: Prueba.fecha(semana: 1, dia: 1, 19, 30))))

        for (nombre, despues) in cambios {
            for hecho in hechos {
                XCTAssertEqual(despues.bloque(hecho.id), hecho, "\(nombre) movió un bloque hecho")
            }
            verificarReglas(despues, nombre)
        }
    }

    // MARK: - Fichas de regreso

    func testSoloElPrimerFuiDespuesDeUnaFaltaEsDeRegreso() {
        var e = Prueba.semilla()
        e.ahora = Prueba.fecha(semana: 1, dia: 7, 12)
        let orden = e.bloques.sorted { $0.inicio < $1.inicio }
        e.marcarHecho(orden[0].id)
        // El martes queda sin registrar: el miércoles es el regreso.
        XCTAssertTrue(Planificador.esRegreso(e, orden[2]))
        e.marcarHecho(orden[2].id)

        for bloque in orden[3...6] {
            XCTAssertFalse(
                Planificador.esRegreso(e, bloque),
                "El \(Formato.fechaConDia(bloque.inicio)) no viene de un atraso: el martes ya tuvo su regreso"
            )
            e.marcarHecho(bloque.id)
        }
    }

    func testUnBloqueMovidoOPuenteSiempreEsDeRegreso() {
        var e = Prueba.semilla()
        let orden = e.bloques.sorted { $0.inicio < $1.inicio }
        e.marcarHecho(orden[0].id)
        XCTAssertFalse(Planificador.esRegreso(e, orden[1]))

        var movido = orden[1]
        movido.origen = movido.inicio.mas(dias: -1)
        XCTAssertTrue(Planificador.esRegreso(e, movido))
        var puente = orden[1]
        puente.esPuente = true
        XCTAssertTrue(Planificador.esRegreso(e, puente))
    }

    // MARK: - Ajuste al plan

    func testElAjusteAlPlanCuentaLasVecesSinDecirEstaSemana() throws {
        var e = Prueba.enMomento(1)
        e.movidasPorVentana["3-06:30"] = 1
        XCTAssertEqual(
            try XCTUnwrap(Planificador.ajusteDeRendimiento(e)).pregunta,
            "Tu bloque del miércoles a las 06:30 se movió una vez. ¿Dejamos los miércoles a las 19:30 desde ahora?"
        )

        // El conteo no se reinicia cada semana: dos movidas de semanas distintas no son «esta semana».
        e.movidasPorVentana["3-06:30"] = 2
        XCTAssertEqual(
            try XCTUnwrap(Planificador.ajusteDeRendimiento(e)).pregunta,
            "Tu bloque del miércoles a las 06:30 se movió 2 veces. ¿Dejamos los miércoles a las 19:30 desde ahora?"
        )
    }

    func testElAjusteAlPlanCambiaElHorarioYLosBloquesFuturos() throws {
        var e = Prueba.enMomento(1)
        XCTAssertNil(Planificador.ajusteDeRendimiento(e), "Sin movidas no hay nada que ajustar")

        let bloque = try XCTUnwrap(e.proximo)
        let ventana = try XCTUnwrap(Planificador.ventanaDelPatron(e, para: bloque))
        XCTAssertEqual(ventana.clave, "3-06:30")
        let puente = try XCTUnwrap(Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(.reinicio)).first)
        e = Planificador.aplicar(puente.accion, a: e)
        e.movidasPorVentana[ventana.clave, default: 0] += 1

        let ajuste = try XCTUnwrap(Planificador.ajusteDeRendimiento(e))
        XCTAssertEqual(ajuste.desde, ventana)
        XCTAssertEqual(ajuste.hacia, Ventana(dia: 3, hora: 19, minuto: 30, tipo: .gimnasio, minutos: 45))

        let despues = Planificador.cambiarPatron(e, ajuste: ajuste)

        XCTAssertTrue(despues.patron.contains(ajuste.hacia))
        XCTAssertFalse(despues.patron.contains(ajuste.desde))
        XCTAssertFalse(despues.alternativas.contains(ajuste.hacia))
        let futuros = e.bloques.filter { $0.estado == .planificado && $0.inicio > e.ahora && ventana.contiene($0.inicio) }
        XCTAssertEqual(futuros.count, 5)
        for antes in futuros {
            let movido = despues.bloque(antes.id)
            XCTAssertTrue(movido.inicio.mismoDia(que: antes.inicio))
            XCTAssertEqual(Formato.hora(movido.inicio), "19:30")
            XCTAssertEqual(movido.minutos, 45)
        }
        XCTAssertEqual(despues.bloque(bloque.id), e.bloque(bloque.id), "El bloque puente de hoy no se toca")
        XCTAssertEqual(Planificador.recepcion(despues), Planificador.recepcion(e))
        XCTAssertNil(Planificador.ajusteDeRendimiento(despues), "Un ajuste resuelto no se vuelve a sugerir")
        XCTAssertEqual(
            Planificador.slotsDelPatron(despues, desde: Prueba.fecha(semana: 6, dia: 3, 0, 0), cantidad: 1).first?.fecha,
            Prueba.fecha(semana: 6, dia: 3, 19, 30),
            "Lo que se planifique después usa el horario nuevo"
        )
        verificarReglas(despues)
    }

    func testMantenerElHorarioNoVuelveASugerirElAjuste() {
        var e = Prueba.enMomento(1)
        e.movidasPorVentana["3-06:30"] = 1
        XCTAssertNotNil(Planificador.ajusteDeRendimiento(e))

        e.ajustesResueltos.append("3-06:30")

        XCTAssertNil(Planificador.ajusteDeRendimiento(e))
    }

    func testSinOtroHorarioElMismoDiaNoSeSugiereAjuste() {
        var e = Prueba.enMomento(1)
        e.movidasPorVentana["1-19:30"] = 3
        XCTAssertNil(Planificador.ajusteDeRendimiento(e))
    }

    // MARK: - Propuestas por barrera

    func testCadaBarreraTieneOpcionesValidasEnLosMomentosDeLaDemo() throws {
        let sugerida: [TipoBarrera: String] = [
            .horario: "Usa la holgura", .energia: "Bloque puente", .reinicio: "Bloque puente",
            .cuerpo: "Bloque puente", .otra: "Usa la holgura",
        ]
        for momento in 0...1 {
            let e = Prueba.enMomento(momento)
            let bloque = try XCTUnwrap(e.proximo)
            for barrera in TipoBarrera.allCases {
                let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(barrera))
                XCTAssertEqual(propuestas.first?.etiqueta, sugerida[barrera], "momento \(momento) · \(barrera)")
                verificarPropuestas(propuestas, de: bloque, en: e, "momento \(momento) · \(barrera)")
            }
        }
    }

    func testAnteUnaMolestiaElPuenteEsSuaveYEnCasa() throws {
        let e = Prueba.enMomento(0)
        let propuestas = Planificador.propuestas(e, para: try XCTUnwrap(e.proximo), lectura: Prueba.lectura(.cuerpo))
        guard case let .reubicar(_, slot, true) = propuestas.first?.accion else {
            return XCTFail("La primera opción ante una molestia debería ser un bloque puente")
        }
        XCTAssertEqual(slot.tipo, .casa)
        XCTAssertEqual(slot.minutos, 15)
    }

    func testLosPendientesDeLaSemanaTambienTienenOpciones() throws {
        let e = Prueba.enMomento(3)
        XCTAssertEqual(e.pendientes.count, 4)
        for bloque in e.pendientes {
            for barrera in TipoBarrera.allCases {
                let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(barrera))
                verificarPropuestas(propuestas, de: bloque, en: e, "pendiente \(Formato.fechaConDia(bloque.inicio)) · \(barrera)")
            }
        }
    }

    /// Recorre dos semanas a horas incómodas (madrugada, justo antes de un bloque, medianoche),
    /// con Camila al día y con todo pendiente.
    func testBarridoDeDosSemanasSinOpcionesInvalidas() {
        let horas = [(6, 0), (6, 45), (7, 30), (12, 0), (17, 0), (19, 5), (19, 45), (20, 15), (21, 0), (21, 30), (22, 45), (23, 55)]
        let semilla = Prueba.semilla()
        for dia in 0..<14 {
            for (hora, minuto) in horas {
                let ahora = Prueba.lunes.mas(dias: dia).a(hora, minuto)
                for alDia in [false, true] {
                    var e = semilla
                    e.ahora = ahora
                    if alDia {
                        for bloque in e.bloques where bloque.fin <= ahora { e.marcarHecho(bloque.id) }
                    }
                    let contexto = "\(Formato.fechaConDia(ahora)) \(Formato.hora(ahora))\(alDia ? " al día" : "")"
                    for bloque in e.pendientes + [e.proximo].compactMap({ $0 }) {
                        for barrera in TipoBarrera.allCases {
                            let propuestas = Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(barrera))
                            verificarPropuestas(propuestas, de: bloque, en: e, "\(contexto) · \(barrera)")
                        }
                    }
                    for pausa in Planificador.pausas(e) {
                        verificarPausa(pausa, en: e, "\(contexto) · \(pausa.titulo)")
                    }
                }
            }
        }
    }

    // MARK: - Planificar la semana

    func testCambiarUnBloqueAlPlanificarLaSemanaRespetaLasReglas() throws {
        let e = Prueba.enMomento(3)
        let lunes = Prueba.lunes.mas(dias: 7)
        let semana = e.bloques.filter { $0.inicio.lunes == lunes }
        XCTAssertEqual(semana.count, 4)

        var opciones = 0
        for bloque in semana {
            for slot in Planificador.opcionesDePlanificacion(e, para: bloque) {
                opciones += 1
                XCTAssertEqual(slot.fecha.lunes, lunes, "Se queda en su semana")
                XCTAssertNotEqual(slot.fecha, bloque.inicio)
                XCTAssertGreaterThan(slot.fecha, e.ahora)
                XCTAssertFalse(Planificador.choca(e, inicio: slot.fecha, minutos: slot.minutos))
                XCTAssertFalse(e.bloques.contains { $0.id != bloque.id && $0.inicio.mismoDia(que: slot.fecha) })

                // Lo mismo que hace la tarjeta del domingo al elegir una opción.
                var despues = e
                let i = try XCTUnwrap(despues.bloques.firstIndex { $0.id == bloque.id })
                despues.bloques[i].inicio = slot.fecha
                despues.bloques[i].tipo = slot.tipo
                despues.bloques[i].minutos = slot.minutos
                verificarReglas(despues, "\(Formato.fechaConDia(bloque.inicio)) → \(Formato.fechaConDia(slot.fecha))")
            }
        }
        XCTAssertGreaterThan(opciones, 0, "El domingo hay al menos un bloque que se puede cambiar")
    }
}

// MARK: - Verificaciones comunes

/// Toda propuesta de un bloque: válida en sí misma y sin romper las reglas al aplicarla.
private func verificarPropuestas(_ propuestas: [Propuesta], de bloque: Bloque, en e: EstadoObra, _ contexto: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(propuestas.isEmpty, "Sin opciones (\(contexto))", file: file, line: line)
    let base = Planificador.recepcion(e)
    for propuesta in propuestas {
        let donde = "\(contexto) · \(propuesta.etiqueta)"
        XCTAssertEqual(propuesta.accion.bloque, bloque.id, donde, file: file, line: line)

        switch propuesta.accion {
        case let .reubicar(_, slot, puente):
            XCTAssertFalse(Planificador.choca(e, inicio: slot.fecha, minutos: slot.minutos), "Choca con el trabajo (\(donde))", file: file, line: line)
            XCTAssertGreaterThan(slot.fecha, e.ahora, "Propone una hora que ya pasó (\(donde))", file: file, line: line)
            XCTAssertFalse(
                e.bloques.contains { $0.id != bloque.id && $0.inicio.mismoDia(que: slot.fecha) },
                "Cae en un día ocupado (\(donde))", file: file, line: line
            )
            if puente {
                XCTAssertTrue(slot.fecha.mismoDia(que: max(bloque.inicio, e.ahora)), "El puente cambia de día (\(donde))", file: file, line: line)
            }
        case let .empujar(_, fecha):
            XCTAssertEqual(fecha.diaSemana, 1, "No cae en lunes (\(donde))", file: file, line: line)
            XCTAssertGreaterThan(fecha, bloque.inicio, "Adelanta el bloque en vez de correrlo (\(donde))", file: file, line: line)
        case .pausar:
            XCTFail("Una pausa no es una opción del bloque (\(donde))", file: file, line: line)
        }

        let despues = Planificador.aplicar(propuesta.accion, a: e)
        verificarReglas(despues, donde, file: file, line: line)
        XCTAssertEqual(despues.bloques.count, e.bloques.count, donde, file: file, line: line)
        for hecho in e.hechos {
            XCTAssertEqual(despues.bloque(hecho.id), hecho, "Movió un bloque hecho (\(donde))", file: file, line: line)
        }
        if case .reubicar = propuesta.accion {
            for otro in e.bloques where otro.id != bloque.id {
                XCTAssertEqual(despues.bloque(otro.id), otro, "Movió otro bloque (\(donde))", file: file, line: line)
            }
        } else {
            for antes in e.bloques {
                XCTAssertGreaterThanOrEqual(despues.bloque(antes.id).inicio, antes.inicio, "Adelantó un bloque (\(donde))", file: file, line: line)
            }
        }
        if let base, let nueva = Planificador.recepcion(despues) {
            XCTAssertEqual(propuesta.impactoDias, max(0, base.dias(hasta: nueva)), "Impacto mal calculado (\(donde))", file: file, line: line)
        }
    }
}

/// Una pausa corre lo que viene hasta su fecha, nunca adelanta nada y no deja lo hecho atrás.
private func verificarPausa(_ pausa: Propuesta, en e: EstadoObra, _ contexto: String, file: StaticString = #filePath, line: UInt = #line) {
    guard case let .pausar(hasta) = pausa.accion else {
        return XCTFail("No es una pausa (\(contexto))", file: file, line: line)
    }
    XCTAssertEqual(hasta.diaSemana, 1, "La pausa no termina un lunes (\(contexto))", file: file, line: line)
    XCTAssertGreaterThan(hasta, e.ahora, contexto, file: file, line: line)

    let despues = Planificador.aplicar(pausa.accion, a: e)
    verificarReglas(despues, contexto, file: file, line: line)
    for antes in e.bloques {
        XCTAssertGreaterThanOrEqual(despues.bloque(antes.id).inicio, antes.inicio, "La pausa adelantó un bloque (\(contexto))", file: file, line: line)
    }
    for antes in e.bloques where antes.estado == .planificado && antes.inicio >= e.ahora.inicioDelDia {
        XCTAssertGreaterThanOrEqual(despues.bloque(antes.id).inicio, hasta, "Quedó un bloque dentro de la pausa (\(contexto))", file: file, line: line)
    }
    for hecho in e.hechos {
        XCTAssertEqual(despues.bloque(hecho.id), hecho, "La pausa movió un bloque hecho (\(contexto))", file: file, line: line)
    }
    XCTAssertGreaterThan(pausa.impactoDias, 0, "Una pausa que no mueve nada (\(contexto))", file: file, line: line)
}
