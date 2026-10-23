import EventKit
import Foundation

/// Lee la semana de pega de Camila desde el calendario «Camila · Dominó» del iPhone: un calendario
/// de Google que llega por la cuenta configurada en Ajustes, sin iniciar sesión en la app.
/// Solo se lee ese calendario. Los demás no se muestran ni se guardan: el concurso prohíbe
/// usar datos personales reales.
@MainActor
enum CalendarioPega {
    static let nombre = "Camila · Dominó"
    /// Título normalizado que se busca entre los calendarios del iPhone.
    static let clave = "camiladomino"

    /// Por qué no se pudo leer. En todos los casos la app sigue con la semana de ejemplo.
    enum Problema: Error, Equatable {
        case sinPermiso, sinCalendario, sinEventos

        var texto: String {
            switch self {
            case .sinPermiso: "Sin acceso a los calendarios. Puedes darlo en Ajustes."
            case .sinCalendario: "No hay un calendario «Camila · Dominó» en este iPhone."
            case .sinEventos: "«Camila · Dominó» no tiene eventos en estas \(Escenario.semanasDePega) semanas."
            }
        }
    }

    struct Lectura {
        /// Título tal como aparece en el iPhone.
        let calendario: String
        let eventos: [EventoPega]
    }

    private static let almacen = EKEventStore()

    /// Pide acceso completo la primera vez (iOS 17+) y lee el calendario.
    static func conectar(desde lunes: Date) async -> Result<Lectura, Problema> {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            _ = try? await almacen.requestFullAccessToEvents()
        }
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            almacen.refreshSourcesIfNecessary()
        }
        return leer(desde: lunes)
    }

    /// Eventos con hora desde el lunes del plan hasta diez semanas después. No pide permiso.
    static func leer(desde lunes: Date) -> Result<Lectura, Problema> {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return .failure(.sinPermiso) }

        // De los otros calendarios solo se compara el título, y no se guarda nada.
        let calendarios = almacen.calendars(for: .event).filter { normalizar($0.title) == clave }
        guard let calendario = calendarios.first else { return .failure(.sinCalendario) }

        let fin = lunes.mas(dias: 7 * Escenario.semanasDePega)
        let predicado = almacen.predicateForEvents(withStart: lunes, end: fin, calendars: calendarios)
        var eventos: [EventoPega] = []
        for evento in almacen.events(matching: predicado)
        where !evento.isAllDay && evento.status != .canceled && evento.endDate > evento.startDate {
            let titulo = evento.title ?? ""
            let pega = EventoPega(titulo: titulo.isEmpty ? "Pega" : titulo, inicio: evento.startDate, fin: evento.endDate)
            // Si hay dos calendarios con el mismo nombre, un evento repetido cuenta una vez.
            if !eventos.contains(where: { $0.titulo == pega.titulo && $0.inicio == pega.inicio && $0.fin == pega.fin }) {
                eventos.append(pega)
            }
        }
        guard !eventos.isEmpty else { return .failure(.sinEventos) }
        return .success(Lectura(calendario: calendario.title, eventos: eventos.sorted { $0.inicio < $1.inicio }))
    }

    /// "Camila · Dominó" → "camiladomino": minúsculas, sin tildes, símbolos ni espacios.
    static func normalizar(_ titulo: String) -> String {
        titulo
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formato.locale)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
