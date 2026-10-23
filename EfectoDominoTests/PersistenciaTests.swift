import XCTest
@testable import EfectoDomino

/// El plan guardado en el iPhone se tiene que seguir leyendo aunque cambien los nombres del código.
final class PersistenciaTests: XCTestCase {

    func testElArchivoGuardadoMantieneLaClaveDeLaPrimeraVersion() throws {
        let estado = Prueba.semilla()
        let datos = try JSONEncoder().encode(estado)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        XCTAssertNotNil(json["pega"], "Los eventos de trabajo se guardan con la clave de la primera versión")
        XCTAssertNil(json["trabajo"])

        let leido = try JSONDecoder().decode(EstadoObra.self, from: datos)
        XCTAssertEqual(leido.trabajo, estado.trabajo)
        XCTAssertEqual(leido.bloques, estado.bloques)
        XCTAssertEqual(leido.patron, estado.patron)
    }
}
