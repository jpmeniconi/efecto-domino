import XCTest
@testable import EfectoDomino

/// El respaldo sin modelo: tiene que entender lo que Camila escribiría en la demo.
final class LectorLocalTests: XCTestCase {

    private func barrera(_ texto: String) -> TipoBarrera {
        LectorLocal.leer(texto).barrera
    }

    func testFrasesTipicas() {
        XCTAssertEqual(barrera("se alargó la reunión"), .horario)
        XCTAssertEqual(barrera("estoy muerta"), .energia)
        XCTAssertEqual(barrera("ya perdí la semana, parto el lunes"), .reinicio)
        XCTAssertEqual(barrera("me duele la espalda"), .cuerpo)
    }

    func testAtajosDelPanelAjustar() {
        XCTAssertEqual(barrera("Se alargó la reunión"), .horario)
        XCTAssertEqual(barrera("Estoy agotada"), .energia)
        XCTAssertEqual(barrera("Ya perdí la semana"), .reinicio)
        XCTAssertEqual(barrera("Me duele la espalda"), .cuerpo)
    }

    func testOtrasFormasDeDecirlo() {
        let casos: [(String, TipoBarrera)] = [
            ("No alcancé", .horario),
            ("Se alargó la reunión y no alcanzo", .horario),
            ("No tengo tiempo", .horario),
            ("Hay taco y no llego", .horario),
            ("No llegué a la hora", .horario),
            ("Me quedé pegada en la pega", .horario),
            ("Estoy muerta, no me da el cuerpo", .energia),
            ("No me da el cuerpo", .energia),
            ("No dormí nada", .energia),
            ("Mucho cansancio", .energia),
            ("No tengo ganas", .energia),
            ("Ya perdí la semana, mejor parto el lunes", .reinicio),
            ("Mejor parto de cero", .reinicio),
            ("Fallé otra vez", .reinicio),
            ("Me duele la espalda de estar sentada", .cuerpo),
            ("Ando resfriada", .cuerpo),
            ("Me torcí el tobillo", .cuerpo),
            ("Se me olvidó el bolso", .otra),
        ]
        for (texto, esperada) in casos {
            XCTAssertEqual(barrera(texto), esperada, texto)
        }
    }

    /// Igual que el modelo: reinicio, luego cuerpo, luego energía y al final horario.
    func testPrioridadCuandoAparecenVarias() {
        XCTAssertEqual(barrera("Estoy muerta y ya perdí la semana"), .reinicio)
        XCTAssertEqual(barrera("Me duele la espalda y estoy cansada"), .cuerpo)
        XCTAssertEqual(barrera("Estoy cansada porque se alargó la reunión"), .energia)
    }

    func testNoDependeDeMayusculasNiTildes() {
        XCTAssertEqual(barrera("SE ALARGÓ LA REUNIÓN"), .horario)
        XCTAssertEqual(barrera("ya perdi la semana"), .reinicio)
        XCTAssertEqual(barrera("me duele la espálda"), .cuerpo)
    }

    func testSiempreSeIdentificaComoLecturaLocalYTraeUnaFrase() {
        for texto in ["Se alargó la reunión", "Estoy agotada", "Ya perdí la semana", "Me duele la espalda", "Se me olvidó el bolso"] {
            let lectura = LectorLocal.leer(texto)
            XCTAssertEqual(lectura.fuente, .local, texto)
            XCTAssertFalse(lectura.resumen.isEmpty, texto)
        }
    }
}
