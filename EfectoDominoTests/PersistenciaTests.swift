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

    func testUnRegistroGuardadoAntesDeLasFotosSeSigueLeyendo() throws {
        let json = #"{"fecha": 790000000, "disfrute": "bien", "espalda": "mejor", "ayudo": ["Era corto"]}"#
        let registro = try JSONDecoder().decode(Registro.self, from: Data(json.utf8))
        XCTAssertNil(registro.foto)
        XCTAssertEqual(registro.disfrute, .bien)
        XCTAssertEqual(registro.ayudo, ["Era corto"])

        var conFoto = registro
        conFoto.foto = "foto-mat"
        let leido = try JSONDecoder().decode(Registro.self, from: JSONEncoder().encode(conFoto))
        XCTAssertEqual(leido.foto, "foto-mat")
    }
}
