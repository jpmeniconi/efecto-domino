import XCTest
@testable import EfectoDomino

final class ModoJuegoTests: XCTestCase {
    /// El lunes de la demo es el día 15 del ciclo: Camila ya tiene su historial y Javiera puso la de hoy a las 17:00.
    func testElLunesDeLaDemoNoParteEnCero() {
        let e = Prueba.enMomento(0)
        let partida = Partida(estado: e)
        XCTAssertEqual(partida.ciclo, 0)
        XCTAssertEqual(partida.hoy, 14)
        XCTAssertEqual(partida.camila.count, Partida.historialCamila.count)
        XCTAssertEqual(partida.javiera.count, 11)
        XCTAssertEqual(partida.aviso(ahora: e.ahora), "Javiera puso una ficha hace 2 horas. Te toca.")
    }

    /// Máximo una ficha por día: dos bloques hechos el mismo día ponen una sola, y el turno se cierra.
    func testUnaFichaPorDia() {
        var e = Prueba.enMomento(0)
        let lunes = e.bloques.firstIndex { $0.inicio.mismoDia(que: e.ahora) }!
        e.bloques[lunes].estado = .hecho
        e.bloques.append(Bloque(tipo: .casa, inicio: e.ahora.a(7), minutos: 15, estado: .hecho))
        let partida = Partida(estado: e)
        XCTAssertEqual(partida.camila.count, Partida.historialCamila.count + 1)
        XCTAssertNil(partida.aviso(ahora: e.ahora))
    }

    /// Antes de la hora de Javiera no hay turno: nunca se muestra que alguien no ha puesto su ficha.
    func testSinAvisoAntesDeQueJavieraPonga() {
        let e = Prueba.enMomento(1)
        XCTAssertNil(Partida(estado: e).aviso(ahora: e.ahora))
    }

    /// Un ciclo nuevo parte sin el historial ficticio y el récord sigue siendo el mejor ciclo.
    func testCicloNuevoGuardaElRecord() {
        var e = Prueba.semilla()
        e.ahora = e.inicioObra.mas(dias: 14).a(12)
        let partida = Partida(estado: e)
        XCTAssertEqual(partida.ciclo, 1)
        XCTAssertEqual(partida.hoy, 0)
        XCTAssertTrue(partida.camila.isEmpty)
        XCTAssertEqual(partida.record, Partida.recordDeEnero)
    }

    /// Las 28 fichas del dominó, del doble cero al doble seis, sin repetir: una por día del ciclo.
    func testJuegoCompleto() {
        XCTAssertEqual(Partida.juego.count, Partida.dias)
        XCTAssertEqual(Set(Partida.juego.map { "\($0.0)-\($0.1)" }).count, Partida.dias)
        XCTAssertTrue(Partida.juego.first! == (0, 0) && Partida.juego.last! == (6, 6))
    }
}
