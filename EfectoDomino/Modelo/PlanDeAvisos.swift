import Foundation

/// Preferencias del teléfono, separadas de obra.json para conservar los planes ya guardados.
struct PreferenciasDeAvisos: Codable, Equatable {
    var activadas = false
    var preparacion = true
    var registro = false
    var refuerzo = true
    var semana = true
    var minutosAntes = 30
    var descansoDesde = 22
    var descansoHasta = 8
    var sonido = false
}

struct RefuerzoDelDia: Codable, Equatable {
    /// Hora real del primer registro del día: abrir la app no posterga ni repite el reconocimiento.
    let fecha: Date
    var bloque: UUID
}

struct AvisoProgramado: Identifiable, Equatable {
    enum Tipo: String, Codable { case preparacion, registro, refuerzo, semana }
    let id: String
    let fecha: Date
    let titulo: String
    let texto: String
    let tipo: Tipo
    var bloque: UUID? = nil

    var prioridad: Int {
        switch tipo {
        case .refuerzo: 0
        case .preparacion: 1
        case .registro: 2
        case .semana: 3
        }
    }
}

/// Solo usa acciones ya confirmadas. Las fechas se comparan con el reloj real, nunca con el de demo.
enum PlanDeAvisos {
    static let prefijo = "domino."

    static func calcular(
        _ estado: EstadoObra, preferencias p: PreferenciasDeAvisos,
        refuerzo: RefuerzoDelDia? = nil, consumidos: [Date] = [], refuerzosConsumidos: [Date] = [], ahora: Date
    ) -> [AvisoProgramado] {
        guard p.activadas else { return [] }
        var candidatos: [AvisoProgramado] = []

        for bloque in estado.bloques where bloque.estado == .planificado {
            if let hasta = estado.pausaHasta, bloque.inicio < hasta { continue }
            let cuando = "\(Formato.diaConNumero(bloque.inicio).lowercased()) a las \(Formato.hora(bloque.inicio))"
            if p.preparacion && bloque.inicio > ahora {
                let fecha = horaPermitida(bloque.inicio.mas(minutos: -p.minutosAntes), antesDelBloque: true, preferencias: p)
                candidatos.append(AvisoProgramado(
                    id: prefijo + "preparacion.\(bloque.id)", fecha: fecha,
                    titulo: "Tu próximo bloque",
                    texto: "\(bloque.tipo.nombre), \(bloque.minutos) min · \(cuando). Puedes dejar lo que necesitas a mano.",
                    tipo: .preparacion, bloque: bloque.id
                ))
            }
            if p.registro {
                let fecha = horaPermitida(bloque.fin.mas(minutos: 20), antesDelBloque: false, preferencias: p)
                candidatos.append(AvisoProgramado(
                    id: prefijo + "registro.\(bloque.id)", fecha: fecha,
                    titulo: "¿Quieres registrar este bloque?",
                    texto: "\(bloque.tipo.nombre) · \(cuando). Si fuiste, puedes guardar cómo lo pasaste.",
                    tipo: .registro, bloque: bloque.id
                ))
            }
        }

        if p.refuerzo, let refuerzo,
           let bloque = estado.bloques.first(where: { $0.id == refuerzo.bloque && $0.estado == .hecho && $0.registro != nil }) {
            let fecha = horaPermitida(refuerzo.fecha.mas(minutos: 10), antesDelBloque: false, preferencias: p)
            let total = estado.fichasEnPie
            let nivel = NivelDeFichas(fichas: total)
            let titulo: String
            if total % NivelDeFichas.fichasPorMano == 0 {
                titulo = "Nivel \(nivel.numero): \(nivel.nombre)"
            } else if bloque.esRegreso {
                titulo = "Retomaste tu plan"
            } else {
                titulo = "Una ficha más en tu muro"
            }
            candidatos.append(AvisoProgramado(
                id: prefijo + "refuerzo." + claveDelDia(refuerzo.fecha), fecha: fecha,
                titulo: titulo, texto: "Ya tienes \(total) fichas en pie. El bloque que registraste queda en tu avance.",
                tipo: .refuerzo
            ))
        }

        if p.semana {
            // Solo semanas que tienen bloques y que Camila todavía no confirmó.
            let semanas = Set(estado.bloques.filter { $0.estado == .planificado }.map { $0.inicio.lunes })
            for lunes in semanas where !estado.semanasConfirmadas.contains(lunes) {
                let domingo = lunes.mas(dias: -1).a(18)
                let fecha = horaPermitida(domingo, antesDelBloque: false, preferencias: p)
                if let hasta = estado.pausaHasta, fecha < hasta { continue }
                let cantidad = estado.bloques.filter { $0.inicio.lunes == lunes && $0.estado == .planificado }.count
                candidatos.append(AvisoProgramado(
                    id: prefijo + "semana." + claveDelDia(lunes), fecha: fecha,
                    titulo: "Tu próxima semana",
                    texto: "Tienes \(cantidad) \(cantidad == 1 ? "bloque" : "bloques") en tu plan. Puedes revisar los horarios y dejarla lista.",
                    tipo: .semana
                ))
            }
        }

        // El reconocimiento tiene prioridad. Como máximo dos avisos y al menos media hora entre ellos.
        var elegidos: [AvisoProgramado] = []
        for aviso in candidatos.filter({ $0.fecha > ahora }).sorted(by: {
            ($0.prioridad, $0.fecha, $0.id) < ($1.prioridad, $1.fecha, $1.id)
        }) {
            let delDia = elegidos.filter { $0.fecha.mismoDia(que: aviso.fecha) }
            let anteriores = consumidos.filter { $0.mismoDia(que: aviso.fecha) }
            if aviso.tipo == .refuerzo && refuerzosConsumidos.contains(where: { $0.mismoDia(que: aviso.fecha) }) { continue }
            guard delDia.count + anteriores.count < 2,
                  (delDia.map(\.fecha) + anteriores).allSatisfy({ abs($0.timeIntervalSince(aviso.fecha)) >= 30 * 60 }) else { continue }
            elegidos.append(aviso)
        }
        return Array(elegidos.sorted { ($0.fecha, $0.id) < ($1.fecha, $1.id) }.prefix(48))
    }

    static func horaPermitida(_ fecha: Date, antesDelBloque: Bool, preferencias p: PreferenciasDeAvisos) -> Date {
        if fecha.hora < p.descansoHasta {
            return antesDelBloque ? fecha.mas(dias: -1).a(p.descansoDesde - 2) : fecha.a(p.descansoHasta)
        }
        if fecha.hora >= p.descansoDesde {
            return antesDelBloque ? fecha.a(p.descansoDesde - 2) : fecha.mas(dias: 1).a(p.descansoHasta)
        }
        return fecha
    }

    private static func claveDelDia(_ fecha: Date) -> String {
        let c = Calendar.obra.dateComponents([.year, .month, .day], from: fecha)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }
}
