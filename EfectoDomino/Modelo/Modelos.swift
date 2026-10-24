import Foundation

// MARK: - Bloques de la obra

enum TipoBloque: String, Codable, CaseIterable, Identifiable {
    case gimnasio, caminata, casa

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .gimnasio: "Gimnasio"
        case .caminata: "Caminata"
        case .casa: "En casa"
        }
    }

    var simbolo: String {
        switch self {
        case .gimnasio: "dumbbell.fill"
        case .caminata: "figure.walk"
        case .casa: "figure.flexibility"
        }
    }
}

enum EstadoBloque: String, Codable {
    case planificado, hecho
}

enum Sensacion: String, Codable, CaseIterable, Identifiable {
    case mejor, igual, peor

    var id: String { rawValue }
    var nombre: String { rawValue.conMayuscula }
}

/// La experiencia agradable predice el hábito (Kaushal y Rhodes, 2015).
enum Disfrute: String, Codable, CaseIterable, Identifiable {
    case bien, normal, mal

    var id: String { rawValue }
    var nombre: String { rawValue.conMayuscula }
}

struct Registro: Codable, Hashable {
    var fecha: Date
    var disfrute: Disfrute?
    var espalda: Sensacion?
    var ayudo: [String]
    /// Recurso de `Assets.xcassets` o JPEG en `Application Support/fotos/`. Opcional: así el plan
    /// guardado antes de las fotos se sigue leyendo.
    var foto: String? = nil
}

struct Bloque: Identifiable, Codable, Hashable {
    var id = UUID()
    var tipo: TipoBloque
    var inicio: Date
    var minutos: Int
    var estado: EstadoBloque = .planificado
    /// Fecha original si Camila lo movió: se dibuja como fantasma en la carta Gantt.
    var origen: Date?
    /// Bloque corto para retomar. Cuenta completo.
    var esPuente = false
    /// Hecho después de un atraso: la micro-recompensa por volver (Milkman et al., 2021).
    var esRegreso = false
    var preparacion: [String] = []
    var registro: Registro?

    var fin: Date { inicio.mas(minutos: minutos) }
}

extension Array where Element == Bloque {
    /// Cada bloque hecho deja una ficha en pie (sin contar las visitas de enero).
    var fichasEnPie: Int { filter { $0.estado == .hecho }.count }

    var regresos: Int { filter { $0.estado == .hecho && $0.esRegreso }.count }
}

// MARK: - Contexto ficticio de Camila

struct EventoTrabajo: Identifiable, Codable, Hashable {
    var id = UUID()
    var titulo: String
    var inicio: Date
    var fin: Date
}

/// Espacio semanal recurrente, por ejemplo: lunes 19:30, gimnasio, 45 min.
struct Ventana: Codable, Hashable {
    var dia: Int // 1 = lunes … 7 = domingo
    var hora: Int
    var minuto: Int
    var tipo: TipoBloque
    var minutos: Int

    func slot(enSemanaDe lunes: Date) -> Slot {
        Slot(fecha: lunes.mas(dias: dia - 1).a(hora, minuto), tipo: tipo, minutos: minutos)
    }

    /// "3-06:30" = miércoles 06:30.
    var clave: String { "\(dia)-\(Formato.hora(hora, minuto))" }

    func contiene(_ fecha: Date) -> Bool {
        fecha.diaSemana == dia && fecha.hora == hora && fecha.minuto == minuto
    }
}

struct Slot: Hashable {
    let fecha: Date
    let tipo: TipoBloque
    let minutos: Int
}

struct Proyecto: Codable, Hashable {
    /// No se muestra, pero se guarda en obra.json: sin él, una versión anterior de la app no podría
    /// leer el plan y partiría de cero sin avisar.
    var nombre: String
    /// Fichas de las primeras seis semanas: la frecuencia, no la intensidad.
    var meta: Int
    /// Las seis visitas de enero: no se cuentan de nuevo, pero no se parte de cero.
    var visitasPrevias: Int
    /// Bloques comprometidos por semana. Nunca se exige más para "recuperar".
    var porSemana: Int
    var semanas: Int
}

struct EstadoObra: Codable {
    /// El muro completo incluye las visitas de enero; la meta del plan cuenta solo sus bloques.
    var fichasEnPie: Int { proyecto.visitasPrevias + bloques.fichasEnPie }

    var proyecto: Proyecto
    var patron: [Ventana]
    var alternativas: [Ventana]
    var bloques: [Bloque]
    var trabajo: [EventoTrabajo]
    /// Reloj del escenario: el plan y sus pantallas usan esta hora. Reiniciar y conectar el calendario
    /// usan la fecha real, porque el plan vuelve a partir el lunes de esta semana.
    var ahora: Date
    var inicioObra: Date
    var recepcionBase: Date?
    var ajustes = 0
    var pausaHasta: Date?
    /// Lunes de las semanas que Camila ya revisó (la planificación del fin de semana).
    var semanasConfirmadas: [Date] = []
    /// Cuántas veces se movió cada horario del patrón: así el plan aprende de su semana real.
    var movidasPorVentana: [String: Int] = [:]
    /// Ajustes al plan que ya se resolvieron (aceptados o descartados).
    var ajustesResueltos: [String] = []

    /// `trabajo` se guarda con la clave «pega» de la primera versión: así el plan que ya está
    /// guardado en el iPhone se sigue leyendo.
    private enum CodingKeys: String, CodingKey {
        case proyecto, patron, alternativas, bloques, ahora, inicioObra, recepcionBase, ajustes, pausaHasta
        case semanasConfirmadas, movidasPorVentana, ajustesResueltos
        case trabajo = "pega"
    }
}

// MARK: - Lectura y propuestas

enum TipoBarrera: String, Codable, CaseIterable {
    case horario, energia, reinicio, cuerpo, otra

    var nombre: String {
        switch self {
        case .horario: "Choque de horario"
        case .energia: "Poca energía"
        case .reinicio: "Ganas de empezar de nuevo"
        case .cuerpo: "Molestia física"
        case .otra: "Algo cambió"
        }
    }
}

/// Quién hizo la lectura: el modelo en el dispositivo o el respaldo por palabras clave.
enum FuenteLectura: String, Codable {
    case dispositivo, local
}

struct Lectura: Equatable {
    var barrera: TipoBarrera
    var resumen: String
    var fuente: FuenteLectura
}

struct Propuesta: Identifiable, Equatable {
    enum Accion: Equatable {
        /// Mueve solo este bloque (holgura o bloque puente). No afecta al resto.
        case reubicar(bloque: UUID, slot: Slot, puente: Bool)
        /// Lleva el bloque a una fecha del patrón y corre los siguientes un espacio: efecto dominó.
        case empujar(bloque: UUID, fecha: Date)
        /// Detiene la obra hasta una fecha sin perder lo construido.
        case pausar(hasta: Date)

        var bloque: UUID? {
            switch self {
            case let .reubicar(id, _, _), let .empujar(id, _): id
            case .pausar: nil
            }
        }
    }

    let id = UUID()
    var etiqueta: String
    var titulo: String
    var detalle: String
    var simbolo: String
    var accion: Accion
    var confirmacion: String
    var impactoDias = 0

    var impactoTexto: String {
        impactoDias == 0 ? "Tu meta no se mueve" : "Tu meta se corre \(Formato.dias(impactoDias))"
    }
}
