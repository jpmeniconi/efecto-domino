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

#if DEBUG
extension CalendarioPega {
    /// Solo en el simulador, que no tiene Google: crea un calendario local «Camila · Dominó» con una
    /// pega distinta a la de ejemplo, y otro calendario que la app debe ignorar.
    static func crearCalendarioDePrueba(desde lunes: Date) async {
        #if targetEnvironment(simulator)
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            _ = try? await almacen.requestFullAccessToEvents()
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
              let fuente = almacen.sources.first(where: { $0.sourceType == .local }) ?? almacen.defaultCalendarForNewEvents?.source
        else {
            print("[Efecto Dominó] Sin acceso para crear el calendario de prueba.")
            return
        }
        do {
            let camila = try calendarioDePrueba(nombre, en: fuente)
            // Cada semana: lunes temprano, martes y viernes en la tarde, jueves en terreno.
            try eventoDePrueba("Reunión de coordinación", en: camila, inicio: lunes.a(8, 30), fin: lunes.a(10, 0), semanal: true)
            try eventoDePrueba("Comité de obra", en: camila, inicio: lunes.mas(dias: 1).a(17, 0), fin: lunes.mas(dias: 1).a(19, 30), semanal: true)
            try eventoDePrueba("Visita a terreno", en: camila, inicio: lunes.mas(dias: 3).a(7, 30), fin: lunes.mas(dias: 3).a(9, 0), semanal: true)
            try eventoDePrueba("Revisión de presupuesto", en: camila, inicio: lunes.mas(dias: 4).a(16, 0), fin: lunes.mas(dias: 4).a(19, 0), semanal: true)
            // Choca con el gimnasio del primer lunes a las 19:30: ese bloque tiene que esquivarla.
            try eventoDePrueba("Reunión con mandante que se alarga", en: camila, inicio: lunes.a(18, 30), fin: lunes.a(20, 30))
            // De todo el día: se ignora, así que la caminata de ese sábado se queda.
            try eventoDePrueba("Feriado de prueba", en: camila, inicio: lunes.mas(dias: 5), fin: lunes.mas(dias: 5).a(23, 59), todoElDia: true)
            // En otro calendario: la app no lo lee, así que la caminata del sábado siguiente también se queda.
            let otro = try calendarioDePrueba("Otro calendario de prueba", en: fuente)
            try eventoDePrueba("Evento de otro calendario", en: otro, inicio: lunes.mas(dias: 12).a(10, 0), fin: lunes.mas(dias: 12).a(11, 30))
            try almacen.commit()
        } catch {
            print("[Efecto Dominó] No se pudo crear el calendario de prueba: \(error)")
        }
        #else
        print("[Efecto Dominó] El calendario de prueba se crea solo en el simulador.")
        #endif
    }

    #if targetEnvironment(simulator)
    /// Reemplaza el calendario de prueba si ya existía: correr el atajo dos veces no duplica nada.
    private static func calendarioDePrueba(_ titulo: String, en fuente: EKSource) throws -> EKCalendar {
        for viejo in almacen.calendars(for: .event)
        where viejo.source.sourceIdentifier == fuente.sourceIdentifier && normalizar(viejo.title) == normalizar(titulo) {
            try almacen.removeCalendar(viejo, commit: true)
        }
        let calendario = EKCalendar(for: .event, eventStore: almacen)
        calendario.title = titulo
        calendario.source = fuente
        try almacen.saveCalendar(calendario, commit: true)
        return calendario
    }

    private static func eventoDePrueba(_ titulo: String, en calendario: EKCalendar, inicio: Date, fin: Date, semanal: Bool = false, todoElDia: Bool = false) throws {
        let evento = EKEvent(eventStore: almacen)
        evento.calendar = calendario
        evento.title = titulo
        evento.startDate = inicio
        evento.endDate = fin
        evento.isAllDay = todoElDia
        if semanal {
            evento.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: EKRecurrenceEnd(occurrenceCount: Escenario.semanasDePega)))
        }
        try almacen.save(evento, span: .futureEvents, commit: false)
    }
    #endif
}
#endif
