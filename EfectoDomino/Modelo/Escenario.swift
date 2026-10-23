import Foundation

/// Escenario ficticio de Camila. No corresponde a ninguna persona real.
enum Escenario {
    static let ayudas = ["Tenía el bolso listo", "Bloqueé la agenda", "Era corto", "Fui con alguien", "Salí a la hora"]

    /// Checklist antes de salir: reduce la fricción del momento de partir.
    static func preparacion(para tipo: TipoBloque) -> [String] {
        switch tipo {
        case .gimnasio: ["Bolso listo", "Zapatillas a mano", "Agenda bloqueada", "Comida resuelta"]
        case .caminata: ["Zapatillas a mano", "Ruta elegida", "Agenda bloqueada"]
        case .casa: ["Espacio despejado", "Mat a mano", "Celular en silencio"]
        }
    }

    /// Frecuencia antes que intensidad: cuatro bloques por semana, dos de ellos cortos.
    /// El miércoles 06:30 es el horario que eligió Camila (y la alarma que apaga).
    static let patron: [Ventana] = [
        Ventana(dia: 1, hora: 19, minuto: 30, tipo: .gimnasio, minutos: 45),
        Ventana(dia: 2, hora: 21, minuto: 15, tipo: .casa, minutos: 15),
        Ventana(dia: 3, hora: 6, minuto: 30, tipo: .gimnasio, minutos: 45),
        Ventana(dia: 6, hora: 10, minuto: 30, tipo: .caminata, minutos: 30),
    ]

    /// Espacios libres de su semana donde cabe un atraso sin mover la obra.
    static let alternativas: [Ventana] = [
        Ventana(dia: 3, hora: 19, minuto: 30, tipo: .gimnasio, minutos: 45),
        Ventana(dia: 4, hora: 21, minuto: 15, tipo: .casa, minutos: 15),
        Ventana(dia: 5, hora: 19, minuto: 30, tipo: .gimnasio, minutos: 45),
        Ventana(dia: 7, hora: 11, minuto: 0, tipo: .caminata, minutos: 40),
    ]

    /// Semanas de trabajo que se arman o se leen del calendario: alcanzan para todo el plan.
    static let semanasDeTrabajo = 10

    /// Su semana de trabajo de ejemplo: martes y jueves llega tarde.
    static func trabajoDeEjemplo(desde lunes: Date) -> [EventoTrabajo] {
        var trabajo: [EventoTrabajo] = []
        for semana in 0..<semanasDeTrabajo {
            let l = lunes.mas(dias: 7 * semana)
            trabajo.append(EventoTrabajo(titulo: "Coordinación de obra", inicio: l.a(17, 0), fin: l.a(18, 45)))
            trabajo.append(EventoTrabajo(titulo: "Comité con subcontratos", inicio: l.mas(dias: 1).a(17, 30), fin: l.mas(dias: 1).a(20, 45)))
            trabajo.append(EventoTrabajo(titulo: "Visita a obra con mandante", inicio: l.mas(dias: 3).a(16, 0), fin: l.mas(dias: 3).a(20, 30)))
        }
        return trabajo
    }

    static let proyecto = Proyecto(nombre: "Sentirme bien en mi cuerpo", meta: 24, visitasPrevias: 6, porSemana: 4, semanas: 6)

    /// Arma el plan desde el lunes. Sin `trabajo` usa la semana de ejemplo; con la del calendario,
    /// los bloques quedan solo donde no chocan con ningún evento y cada semana mantiene los suyos.
    static func semilla(lunes: Date = Date().lunes, trabajo: [EventoTrabajo]? = nil) -> EstadoObra {
        var estado = base(lunes: lunes, trabajo: trabajo ?? trabajoDeEjemplo(desde: lunes))
        adaptarPatron(&estado, desde: lunes)
        let slots = slotsDelPlan(estado, desde: lunes, cantidad: proyecto.meta)
        estado.bloques = slots.map { Bloque(tipo: $0.tipo, inicio: $0.fecha, minutos: $0.minutos) }
        estado.recepcionBase = Planificador.recepcion(estado)
        return estado
    }

    /// Qué horarios del patrón cambia el trabajo, para contarlo en el escenario de demo.
    static func cambiosDePatron(por trabajo: [EventoTrabajo], desde lunes: Date) -> [(desde: Ventana, hacia: Ventana)] {
        var estado = base(lunes: lunes, trabajo: trabajo)
        return adaptarPatron(&estado, desde: lunes)
    }

    private static func base(lunes: Date, trabajo: [EventoTrabajo]) -> EstadoObra {
        EstadoObra(
            proyecto: proyecto,
            patron: patron,
            alternativas: alternativas,
            bloques: [],
            trabajo: trabajo,
            ahora: lunes.a(19, 5),
            inicioObra: lunes
        )
    }

    /// Un horario del patrón que choca con el trabajo la mitad de las semanas o más pasa a un espacio
    /// libre, en un día sin otro bloque y del mismo tipo si se puede: se cambia el horario, no la meta.
    /// Así también el efecto dominó y las pausas, que usan el patrón, mantienen cuatro bloques por semana.
    @discardableResult
    private static func adaptarPatron(_ e: inout EstadoObra, desde lunes: Date) -> [(desde: Ventana, hacia: Ventana)] {
        let umbral = (e.proyecto.semanas + 1) / 2
        var cambios: [(desde: Ventana, hacia: Ventana)] = []
        for i in e.patron.indices {
            let ventana = e.patron[i]
            guard semanasConChoque(e, ventana, desde: lunes) >= umbral else { continue }
            let diasOcupados = Set(e.patron.indices.filter { $0 != i }.map { e.patron[$0].dia })
            let reemplazo = e.alternativas
                .filter { !diasOcupados.contains($0.dia) }
                .map { (ventana: $0, choques: semanasConChoque(e, $0, desde: lunes)) }
                .filter { $0.choques < umbral }
                .min { a, b in
                    (a.ventana.tipo == ventana.tipo ? 0 : 1, a.choques, distancia(a.ventana, ventana))
                        < (b.ventana.tipo == ventana.tipo ? 0 : 1, b.choques, distancia(b.ventana, ventana))
                }?
                .ventana
            guard let reemplazo else { continue }
            e.patron[i] = reemplazo
            e.alternativas.removeAll { $0 == reemplazo }
            cambios.append((ventana, reemplazo))
        }
        return cambios
    }

    /// En cuántas semanas del plan choca ese horario con el trabajo.
    private static func semanasConChoque(_ e: EstadoObra, _ ventana: Ventana, desde lunes: Date) -> Int {
        (0..<e.proyecto.semanas).filter { semana in
            let slot = ventana.slot(enSemanaDe: lunes.mas(dias: 7 * semana))
            return Planificador.choca(e, inicio: slot.fecha, minutos: slot.minutos)
        }.count
    }

    /// Minutos entre dos horarios de la semana.
    private static func distancia(_ a: Ventana, _ b: Ventana) -> Int {
        abs(((a.dia - b.dia) * 24 + a.hora - b.hora) * 60 + a.minuto - b.minuto)
    }

    /// El patrón semana a semana. Si un evento choca con un horario solo esa semana, el bloque va a
    /// un espacio libre de la misma semana (del mismo tipo si se puede): no se pierde y nunca hay
    /// más bloques que los del patrón.
    private static func slotsDelPlan(_ e: EstadoObra, desde lunes: Date, cantidad: Int) -> [Slot] {
        let orden = e.patron.sorted { ($0.dia, $0.hora, $0.minuto) < ($1.dia, $1.hora, $1.minuto) }
        var resultado: [Slot] = []
        var semana = lunes
        while resultado.count < cantidad, semana < lunes.mas(dias: 7 * 52) {
            let delPatron = orden.map { $0.slot(enSemanaDe: semana) }
            var libres = delPatron.filter { !Planificador.choca(e, inicio: $0.fecha, minutos: $0.minutos) }
            var dias = Set(libres.map { $0.fecha.inicioDelDia })
            for chocado in delPatron where !libres.contains(chocado) {
                let espacio = e.alternativas
                    .map { $0.slot(enSemanaDe: semana) }
                    .filter { !dias.contains($0.fecha.inicioDelDia) && !Planificador.choca(e, inicio: $0.fecha, minutos: $0.minutos) }
                    .min { a, b in
                        (a.tipo == chocado.tipo ? 0 : 1, abs(a.fecha.timeIntervalSince(chocado.fecha)))
                            < (b.tipo == chocado.tipo ? 0 : 1, abs(b.fecha.timeIntervalSince(chocado.fecha)))
                    }
                if let espacio {
                    libres.append(espacio)
                    dias.insert(espacio.fecha.inicioDelDia)
                }
            }
            resultado += libres.sorted { $0.fecha < $1.fecha }
            semana = semana.mas(dias: 7)
        }
        return Array(resultado.prefix(cantidad))
    }

    struct Momento: Identifiable {
        var id: String { titulo }
        let titulo: String
        let detalle: String
        let fecha: Date
    }

    /// Momentos de la demo, basados en "el momento en que se cae" de la ficha.
    static func momentos(desde lunes: Date) -> [Momento] {
        [
            Momento(titulo: "Lunes 19:05", detalle: "Se alarga la reunión", fecha: lunes.a(19, 5)),
            Momento(titulo: "Miércoles 06:45", detalle: "Apagó la alarma por cuarta vez", fecha: lunes.mas(dias: 2).a(6, 45)),
            Momento(titulo: "Miércoles 20:15", detalle: "Después del bloque puente", fecha: lunes.mas(dias: 2).a(20, 15)),
            Momento(titulo: "Domingo 23:55", detalle: "Llega el cargo del gimnasio", fecha: lunes.mas(dias: 6).a(23, 55)),
        ]
    }
}
