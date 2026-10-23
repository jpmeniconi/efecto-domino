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

    static func semilla(lunes: Date = Date().lunes) -> EstadoObra {
        let proyecto = Proyecto(nombre: "Sentirme bien en mi cuerpo", meta: 24, fundaciones: 6, porSemana: 4, semanas: 6)

        // Su semana de pega: martes y jueves llega tarde.
        var pega: [EventoPega] = []
        for semana in 0..<10 {
            let l = lunes.mas(dias: 7 * semana)
            pega.append(EventoPega(titulo: "Coordinación de obra", inicio: l.a(17, 0), fin: l.a(18, 45)))
            pega.append(EventoPega(titulo: "Comité con subcontratos", inicio: l.mas(dias: 1).a(17, 30), fin: l.mas(dias: 1).a(20, 45)))
            pega.append(EventoPega(titulo: "Visita a obra con mandante", inicio: l.mas(dias: 3).a(16, 0), fin: l.mas(dias: 3).a(20, 30)))
        }

        var estado = EstadoObra(
            proyecto: proyecto,
            patron: patron,
            alternativas: alternativas,
            bloques: [],
            pega: pega,
            ahora: lunes.a(19, 5),
            inicioObra: lunes
        )
        let slots = Planificador.slotsDelPatron(estado, desde: lunes, cantidad: proyecto.meta)
        estado.bloques = slots.map { Bloque(tipo: $0.tipo, inicio: $0.fecha, minutos: $0.minutos) }
        estado.recepcionBase = Planificador.recepcion(estado)
        return estado
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
