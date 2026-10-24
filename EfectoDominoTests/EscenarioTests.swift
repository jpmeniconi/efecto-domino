import XCTest
@testable import EfectoDomino

/// Los controles de la demo no borran el avance sin preguntar.
final class EscenarioTests: XCTestCase {

    func testReiniciarAvisaLoQueSeBorraAntesDeConfirmar() throws {
        var e = Prueba.enMomento(1)
        XCTAssertEqual(Reinicio.titulo, "¿Reiniciar el escenario?")
        XCTAssertEqual(Reinicio.mensaje(e), "El plan se arma de nuevo desde el lunes de esta semana. No se puede deshacer.")

        e.marcarHecho(try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 1, 19, 30))).id)
        XCTAssertEqual(
            Reinicio.mensaje(e),
            "Se borra 1 ficha en pie y el plan se arma de nuevo desde el lunes de esta semana. No se puede deshacer."
        )

        e.marcarHecho(try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 2, 21, 15))).id)
        e.ajustes = 1
        XCTAssertEqual(
            Reinicio.mensaje(e),
            "Se borran 2 fichas en pie y 1 ajuste, y el plan se arma de nuevo desde el lunes de esta semana. No se puede deshacer."
        )
    }
}
