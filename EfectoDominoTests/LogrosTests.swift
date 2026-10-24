import XCTest
@testable import EfectoDomino

/// Nivel y logros salen del estado: nada se guarda aparte y nada baja por faltar.
final class LogrosTests: XCTestCase {
    private func logro(_ clave: Logro.Clave, en e: EstadoObra) -> Logro {
        Logros.calcular(e).first { $0.id == clave }!
    }

    private func conseguidos(_ e: EstadoObra) -> Set<Logro.Clave> {
        Set(Logros.calcular(e).filter(\.conseguido).map(\.id))
    }

    private func aplicar(_ etiqueta: String, lectura: TipoBarrera, momento: Int) throws -> EstadoObra {
        let e = Prueba.enMomento(momento)
        let bloque = try XCTUnwrap(e.proximo)
        let propuesta = try XCTUnwrap(
            Planificador.propuestas(e, para: bloque, lectura: Prueba.lectura(lectura)).first { $0.etiqueta == etiqueta }
        )
        return Planificador.aplicar(propuesta.accion, a: e)
    }

    func testElNivelSubeCadaSieteFichas() {
        XCTAssertEqual(NivelDeFichas(fichas: 0).numero, 1)
        // Con las seis visitas de enero, a una ficha del nivel 2.
        XCTAssertEqual(NivelDeFichas(fichas: 6).numero, 1)
        XCTAssertEqual(NivelDeFichas(fichas: 6).faltan, 1)
        XCTAssertEqual(NivelDeFichas(fichas: 7).numero, 2)
        XCTAssertEqual(NivelDeFichas(fichas: 7).enMano, 0)
        XCTAssertEqual(NivelDeFichas(fichas: 7).faltan, 7)
        XCTAssertEqual(NivelDeFichas(fichas: 13).numero, 2)
        XCTAssertEqual(NivelDeFichas(fichas: 14).numero, 3)
        // Todo el programa: 6 de enero y 24 bloques.
        XCTAssertEqual(NivelDeFichas(fichas: 30).numero, 5)
    }

    func testAlPartirSoloCuentaEnero() {
        let e = Prueba.semilla()
        XCTAssertEqual(conseguidos(e), [.enero])
        XCTAssertEqual(Logros.siguiente(Logros.calcular(e))?.id, .primeraFicha)
    }

    func testLoSiguienteNuncaPideFaltar() {
        var e = Prueba.semilla()
        for i in e.bloques.indices { e.bloques[i].estado = .hecho }
        XCTAssertTrue(conseguidos(e).isSuperset(of: [.primeraFicha, .tresTipos, .semanaCompleta, .programaCompleto]))
        // Sin registros falta «Lo que te funciona»; la holgura y el puente siguen por lograr, pero no se proponen.
        XCTAssertEqual(Logros.siguiente(Logros.calcular(e))?.id, .loQueTeFunciona)

        for i in e.bloques.indices { e.bloques[i].registro = Registro(fecha: e.ahora, ayudo: []) }
        e.semanasConfirmadas.append(e.inicioObra)
        XCTAssertFalse(conseguidos(e).contains(.holgura))
        XCTAssertNil(Logros.siguiente(Logros.calcular(e)))
    }

    func testPrimeraFichaYSemanaCompleta() {
        var e = Prueba.semilla()
        let semana = e.bloques.filter { $0.inicio.lunes == e.inicioObra }.sorted { $0.inicio < $1.inicio }
        XCTAssertEqual(semana.count, e.proyecto.porSemana)

        e.marcarHecho(semana[0].id)
        XCTAssertTrue(logro(.primeraFicha, en: e).conseguido)
        XCTAssertFalse(logro(.semanaCompleta, en: e).conseguido)
        XCTAssertEqual(logro(.semanaCompleta, en: e).detalle, "Ya hiciste 1 de 4 en una semana. Los cortos cuentan completo.")

        for bloque in semana.dropFirst() { e.marcarHecho(bloque.id) }
        XCTAssertTrue(logro(.semanaCompleta, en: e).conseguido)
    }

    func testHolguraPuenteYDominoSeDistinguen() throws {
        let conHolgura = try aplicar("Usa la holgura", lectura: .horario, momento: 0)
        XCTAssertTrue(logro(.holgura, en: conHolgura).conseguido)
        XCTAssertFalse(logro(.puente, en: conHolgura).conseguido)

        let conPuente = try aplicar("Bloque puente", lectura: .energia, momento: 1)
        XCTAssertTrue(logro(.puente, en: conPuente).conseguido)
        XCTAssertFalse(logro(.holgura, en: conPuente).conseguido)

        // Partir el lunes corre los bloques: es el efecto dominó, no la holgura.
        let conLunes = try aplicar("Partir el lunes", lectura: .reinicio, momento: 1)
        XCTAssertFalse(logro(.holgura, en: conLunes).conseguido)
    }

    func testFichaDeRegreso() {
        var e = Prueba.semilla()
        e.bloques[0].estado = .hecho
        XCTAssertFalse(logro(.regreso, en: e).conseguido)
        e.bloques[0].esRegreso = true
        XCTAssertTrue(logro(.regreso, en: e).conseguido)
    }

    func testSoloElAjusteAceptadoCuenta() throws {
        var e = Prueba.enMomento(1)
        let miercoles = try XCTUnwrap(e.patron.first { $0.dia == 3 })
        e.movidasPorVentana[miercoles.clave] = 1
        let ajuste = try XCTUnwrap(Planificador.ajusteDeRendimiento(e))

        var descartado = e
        descartado.ajustesResueltos.append(ajuste.desde.clave)
        XCTAssertFalse(logro(.ajustePlan, en: descartado).conseguido)

        XCTAssertTrue(logro(.ajustePlan, en: Planificador.cambiarPatron(e, ajuste: ajuste)).conseguido)
    }

    func testSemanaPlanificadaYTiposEnPositivo() {
        var e = Prueba.semilla()
        XCTAssertEqual(logro(.tresTipos, en: e).detalle, "Haz un bloque de cada tipo: gimnasio, caminata y en casa.")
        let gimnasio = e.bloques.first { $0.tipo == .gimnasio }!
        e.marcarHecho(gimnasio.id)
        XCTAssertEqual(logro(.tresTipos, en: e).detalle, "Con caminata y en casa los completas.")

        e.semanasConfirmadas.append(e.inicioObra.mas(dias: 7))
        XCTAssertTrue(logro(.semanaPlanificada, en: e).conseguido)
    }
}
