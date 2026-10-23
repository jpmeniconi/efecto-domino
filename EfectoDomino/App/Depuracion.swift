import Foundation

#if DEBUG
/// Atajos para capturas y pruebas desde la línea de comandos (solo en Debug). Ejemplo:
/// xcrun simctl launch <sim> cl.jpmeniconi.efectodomino -reiniciar YES -momento 1 -abrir ajustar -texto "Ya perdí la semana" -aplicar 0
/// Calendario de la pega: -crearCalendarioDePrueba YES -conectarCalendario YES (NO vuelve a la semana de ejemplo).
enum Depuracion {
    private static let ajustes = UserDefaults.standard

    static var reiniciar: Bool { ajustes.bool(forKey: "reiniciar") }
    static var momento: Int? { entero("momento") }
    static var foco: String? { ajustes.string(forKey: "foco") }
    static var abrir: String? { ajustes.string(forKey: "abrir") }
    static var texto: String? { ajustes.string(forKey: "texto") }
    static var aplicar: Int? { entero("aplicar") }
    static var registrar: Bool { ajustes.bool(forKey: "registrar") }
    /// Crea en el simulador un calendario local «Camila · Dominó» con una pega de prueba.
    static var crearCalendarioDePrueba: Bool { ajustes.bool(forKey: "crearCalendarioDePrueba") }
    static var conectarCalendario: Bool? {
        ajustes.object(forKey: "conectarCalendario") == nil ? nil : ajustes.bool(forKey: "conectarCalendario")
    }

    private static func entero(_ clave: String) -> Int? {
        ajustes.object(forKey: clave) == nil ? nil : ajustes.integer(forKey: clave)
    }
}
#endif
