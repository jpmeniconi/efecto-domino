import XCTest
@testable import EfectoDomino

/// Escenario fijo: la semana de la hackatón. Así las pruebas no dependen del día en que se corren.
enum Prueba {
    static let lunes: Date = Calendar.obra.date(from: DateComponents(year: 2026, month: 10, day: 21))!.lunes

    static func semilla() -> EstadoObra {
        Escenario.semilla(lunes: lunes)
    }

    /// 0: lunes 19:05 · 1: miércoles 06:45 · 2: miércoles 20:15 · 3: domingo 23:55.
    static func enMomento(_ indice: Int) -> EstadoObra {
        var e = semilla()
        e.ahora = Escenario.momentos(desde: e.inicioObra)[indice].fecha
        return e
    }

    static func lectura(_ barrera: TipoBarrera) -> Lectura {
        Lectura(barrera: barrera, resumen: "", fuente: .local)
    }

    /// Día `dia` (1 = lunes) de la semana `semana` (0 = la primera) a una hora.
    static func fecha(semana: Int = 0, dia: Int, _ hora: Int, _ minuto: Int = 0) -> Date {
        lunes.mas(dias: semana * 7 + dia - 1).a(hora, minuto)
    }
}

extension EstadoObra {
    func bloque(_ id: UUID) -> Bloque {
        bloques.first { $0.id == id }!
    }

    func bloque(en fecha: Date) -> Bloque? {
        bloques.first { $0.inicio == fecha }
    }

    /// El mismo que muestra la tarjeta del próximo bloque.
    var proximo: Bloque? {
        bloques
            .filter { $0.estado == .planificado && $0.inicio >= ahora.inicioDelDia }
            .min { $0.inicio < $1.inicio }
    }

    /// Bloques de días anteriores de esta semana que quedaron sin registrar.
    var pendientes: [Bloque] {
        bloques.filter { $0.estado == .planificado && $0.inicio < ahora.inicioDelDia && $0.inicio >= ahora.lunes }
    }

    var hechos: [Bloque] {
        bloques.filter { $0.estado == .hecho }
    }

    mutating func marcarHecho(_ id: UUID) {
        guard let i = bloques.firstIndex(where: { $0.id == id }) else { return }
        bloques[i].estado = .hecho
    }
}

/// Las reglas que ningún cambio del planificador puede romper.
func verificarReglas(_ e: EstadoObra, _ contexto: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let donde = contexto().isEmpty ? "" : " (\(contexto()))"

    for (lunes, bloques) in Dictionary(grouping: e.bloques, by: { $0.inicio.lunes }) {
        XCTAssertLessThanOrEqual(
            bloques.count, e.proyecto.porSemana,
            "La semana del \(Formato.fechaConDia(lunes)) tiene \(bloques.count) bloques: se acumuló deuda\(donde)",
            file: file, line: line
        )
    }
    for (dia, bloques) in Dictionary(grouping: e.bloques, by: { $0.inicio.inicioDelDia }) where bloques.count > 1 {
        XCTFail("El \(Formato.fechaConDia(dia)) tiene \(bloques.count) bloques\(donde)", file: file, line: line)
    }
    for bloque in e.bloques where bloque.estado == .planificado {
        XCTAssertFalse(
            Planificador.choca(e, inicio: bloque.inicio, minutos: bloque.minutos),
            "El bloque del \(Formato.fechaConDia(bloque.inicio)) \(Formato.hora(bloque.inicio)) choca con la pega\(donde)",
            file: file, line: line
        )
    }
}
