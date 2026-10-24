import Foundation
import FoundationModels

enum DisponibilidadIA: Equatable {
    case lista
    case noDisponible(String)

    var descripcion: String {
        switch self {
        case .lista: "Lista"
        case .noDisponible(let motivo): motivo
        }
    }
}

/// Lo único que decide el modelo: qué tipo de barrera hay y cómo reconocerla en una frase.
/// Los horarios y las reglas los pone el `Planificador`.
@Generable(description: "Lectura de lo que le impide a Camila hacer su bloque de ejercicio")
struct LecturaGenerada {
    @Guide(description: "Barrera principal", .anyOf(["horario", "energia", "reinicio", "cuerpo", "otra"]))
    var barrera: String

    @Guide(description: "Frase breve en español de Chile, en segunda persona, que reconoce lo que pasó sin culpar ni motivar. Máximo 20 palabras.")
    var resumen: String
}

/// Lectura con el modelo de lenguaje de Apple, en el dispositivo: nada sale del iPhone.
enum LectorIA {
    static let instrucciones = """
    Eres el módulo de lectura de Dominó, una app que ayuda a Camila a volver a entrenar \
    con un plan que se adapta a su semana. Camila tiene 34 años y es jefa de proyectos en una constructora.

    Lee lo que Camila escribe cuando un bloque de ejercicio no va a ocurrir como estaba planificado \
    y clasifica la barrera principal:
    - horario: le falta tiempo; el trabajo, una reunión o un imprevisto le comió el espacio.
    - energia: está cansada, con sueño o sin energía.
    - reinicio: siente que ya perdió la semana o el avance, quiere partir de cero o "el lunes", o expresa culpa.
    - cuerpo: dolor o molestia física.
    - otra: cualquier otra cosa.
    Si aparecen varias, prioriza reinicio, luego cuerpo, luego energia y luego horario.

    Escribe además una frase breve, cálida y sin juicio, dirigida a Camila de "tú", en español de Chile \
    y con gramática correcta. Describe lo que le pasó; no uses frases motivacionales, no culpes, \
    no des consejos médicos y no propongas horarios: eso lo hace la app.

    Ejemplos:
    «Se alargó la reunión y no alcanzo» → horario: "La reunión se comió el espacio que tenías para entrenar."
    «Estoy muerta, no me da el cuerpo» → energia: "Llegaste sin energía después de un día largo."
    «Ya perdí la semana, mejor parto el lunes» → reinicio: "Sientes que la semana se perdió, pero tu avance sigue ahí."
    «Me duele la espalda de estar sentada» → cuerpo: "La espalda te está pidiendo moverte con más calma."
    """

    static var disponibilidad: DisponibilidadIA {
        let modelo = SystemLanguageModel.default
        switch modelo.availability {
        case .available:
            return modelo.supportsLocale(Locale(identifier: "es_CL")) ? .lista : .noDisponible("Sin soporte de español")
        case .unavailable(.deviceNotEligible):
            return .noDisponible("Equipo no compatible")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .noDisponible("Apple Intelligence desactivado")
        case .unavailable(.modelNotReady):
            return .noDisponible("Modelo descargándose")
        case .unavailable:
            return .noDisponible("No disponible")
        }
    }

    /// Sesión con el modelo ya cargado. En frío, la primera lectura tarda varios segundos;
    /// se usa una sola vez y las siguientes parten con una sesión nueva.
    @MainActor private static var reserva: LanguageModelSession?

    /// Carga el modelo antes de que Camila escriba, para que la lectura no la haga esperar.
    @MainActor static func precalentar() {
        guard reserva == nil, disponibilidad == .lista else { return }
        let sesion = LanguageModelSession(instructions: instrucciones)
        sesion.prewarm()
        reserva = sesion
    }

    @MainActor private static func tomarSesion() -> LanguageModelSession {
        defer { reserva = nil }
        return reserva ?? LanguageModelSession(instructions: instrucciones)
    }

    static func leer(texto: String, bloque: Bloque, ahora: Date) async throws -> Lectura {
        let sesion = await tomarSesion()
        let prompt = """
        Bloque planificado: \(bloque.tipo.nombre), \(Formato.dia(bloque.inicio)) \(Formato.hora(bloque.inicio)), \(bloque.minutos) minutos.
        Momento actual: \(Formato.dia(ahora)) \(Formato.hora(ahora)).
        Camila escribe: «\(texto)»
        """
        let respuesta = try await sesion.respond(
            to: prompt,
            generating: LecturaGenerada.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.2)
        )
        let contenido = respuesta.content
        return Lectura(
            barrera: TipoBarrera(rawValue: contenido.barrera) ?? .otra,
            resumen: contenido.resumen,
            fuente: .dispositivo
        )
    }
}

/// Respaldo sin IA: palabras clave. Se usa si el modelo del iPhone no está disponible o tarda más de 12 segundos.
enum LectorLocal {
    static func leer(_ texto: String) -> Lectura {
        let t = texto.lowercased().folding(options: .diacriticInsensitive, locale: Formato.locale)
        func tiene(_ claves: [String]) -> Bool { claves.contains { t.contains($0) } }

        let barrera: TipoBarrera
        if tiene(["perdi", "lunes", "de cero", "empezar", "parto", "partir", "ya fue", "no tiene sentido", "culpa", "falle", "otra vez"]) {
            barrera = .reinicio
        } else if tiene(["duele", "dolor", "espalda", "lesion", "molest", "enferm", "resfri", "tobillo", "rodilla"]) {
            barrera = .cuerpo
        } else if tiene(["cansa", "agotad", "sueno", "dormi", "reventad", "muert", "sin energia", "sin ganas", "no tengo ganas", "no me da el cuerpo", "flojera"]) {
            barrera = .energia
        } else if tiene(["reunion", "pega", "trabajo", "tarde", "tiempo", "alargo", "alcan", "lleg", "taco", "atras", "obra", "mandante", "comite"]) {
            barrera = .horario
        } else {
            barrera = .otra
        }
        return Lectura(barrera: barrera, resumen: resumenes[barrera] ?? "", fuente: .local)
    }

    private static let resumenes: [TipoBarrera: String] = [
        .horario: "El trabajo se alargó. Busquemos dónde cabe el bloque esta semana.",
        .energia: "Hoy queda poca energía. Un bloque más corto también suma.",
        .reinicio: "Sientes que la semana se perdió, pero tu avance sigue ahí.",
        .cuerpo: "Si el cuerpo pide calma, bajemos la intensidad.",
        .otra: "Algo cambió. Veamos opciones que no te obliguen a partir de cero.",
    ]
}

/// Corre `trabajo` y, si tarda más de `segundos`, responde con un error para usar el respaldo.
@MainActor
func conLimite<T: Sendable>(segundos: Double, _ trabajo: @escaping @Sendable () async throws -> T) async throws -> T {
    let bandera = Bandera()
    return try await withCheckedThrowingContinuation { (continuacion: CheckedContinuation<T, Error>) in
        Task { @MainActor in
            do {
                let resultado = try await trabajo()
                if bandera.tomar() { continuacion.resume(returning: resultado) }
            } catch {
                if bandera.tomar() { continuacion.resume(throwing: error) }
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(segundos))
            if bandera.tomar() { continuacion.resume(throwing: CancellationError()) }
        }
    }
}

@MainActor
private final class Bandera {
    private var tomada = false

    func tomar() -> Bool {
        guard !tomada else { return false }
        tomada = true
        return true
    }
}
