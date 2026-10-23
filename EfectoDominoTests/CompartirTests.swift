import XCTest
@testable import EfectoDomino

/// Compartir es decisión de Camila: el avance como imagen y la invitación a un bloque.
final class CompartirTests: XCTestCase {

    func testLaInvitacionNoDependeDeLaOtraPersona() throws {
        let e = Prueba.enMomento(0)
        let lunes = try XCTUnwrap(e.proximo)

        XCTAssertEqual(
            lunes.invitacion(ahora: e.ahora),
            "¿Te sumas hoy a las 19:30? Voy al gimnasio 45 minutos. Si no puedes, no pasa nada: igual voy."
        )

        let sabado = try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 6, 10, 30)))
        XCTAssertEqual(
            sabado.invitacion(ahora: e.ahora),
            "¿Te sumas el sábado 24 a las 10:30? Voy a caminar 30 minutos. Si no puedes, no pasa nada: igual voy."
        )

        let enCasa = try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 2, 21, 15)))
        XCTAssertNil(enCasa.invitacion(ahora: e.ahora), "Un bloque en casa no se comparte como invitación")
    }

    @MainActor
    func testElReporteDeAvanceSeDibuja() throws {
        var e = Prueba.enMomento(2)
        e.marcarHecho(try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 1, 19, 30))).id)
        let reporte = ReporteDeAvance(bloques: e.bloques, proyecto: e.proyecto, inicioObra: e.inicioObra, ahora: e.ahora)

        let datos = try reporte.png()
        let imagen = try XCTUnwrap(UIImage(data: datos))

        XCTAssertEqual(imagen.size.width * imagen.scale, 1080)
        XCTAssertEqual(imagen.size.height * imagen.scale, 1350)
        let adjunto = XCTAttachment(image: imagen)
        adjunto.name = "Reporte de avance"
        adjunto.lifetime = .keepAlways
        add(adjunto)
    }
}
