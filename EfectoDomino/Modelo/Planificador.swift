import Foundation

/// Reglas duras del plan. Es determinístico: la IA solo interpreta lo que Camila escribe,
/// nunca decide horarios.
///
/// - Nunca se acumula deuda: cada semana tiene a lo más `porSemana` bloques del patrón.
/// - Lo hecho no se mueve ni se borra.
/// - Un atraso se absorbe primero en la holgura de la semana; si no cabe,
///   los bloques siguientes se corren un espacio (efecto dominó) y la recepción se mueve.
enum Planificador {

    // MARK: - Consultas

    static func recepcion(_ e: EstadoObra) -> Date? {
        e.bloques.filter { $0.estado == .planificado }.map(\.inicio).max()
    }

    /// Hecho después de un atraso: deja una ficha de regreso (Milkman et al., 2021). Viene de un
    /// atraso si se movió, si es un bloque puente o si el bloque anterior quedó sin registrar:
    /// así solo el primer «Fui» después de una falta es de regreso, no todos los que siguen.
    static func esRegreso(_ e: EstadoObra, _ bloque: Bloque) -> Bool {
        if bloque.origen != nil || bloque.esPuente { return true }
        let anterior = e.bloques
            .filter { $0.id != bloque.id && $0.inicio < bloque.inicio }
            .max { $0.inicio < $1.inicio }
        return anterior?.estado == .planificado
    }

    static func choca(_ e: EstadoObra, inicio: Date, minutos: Int) -> Bool {
        let fin = inicio.mas(minutos: minutos)
        return e.trabajo.contains { $0.inicio < fin && inicio < $0.fin }
    }

    /// Fechas del patrón semanal desde `desde`, sin choques con el trabajo ni días ya ocupados.
    static func slotsDelPatron(_ e: EstadoObra, desde: Date, cantidad: Int, diasOcupados: Set<Date> = []) -> [Slot] {
        guard cantidad > 0 else { return [] }
        let orden = e.patron.sorted { ($0.dia, $0.hora, $0.minuto) < ($1.dia, $1.hora, $1.minuto) }
        var resultado: [Slot] = []
        var lunes = desde.lunes
        for _ in 0..<520 {
            for ventana in orden {
                let slot = ventana.slot(enSemanaDe: lunes)
                guard slot.fecha >= desde,
                      !diasOcupados.contains(slot.fecha.inicioDelDia),
                      !choca(e, inicio: slot.fecha, minutos: slot.minutos) else { continue }
                resultado.append(slot)
                if resultado.count == cantidad { return resultado }
            }
            lunes = lunes.mas(dias: 7)
        }
        return resultado
    }

    /// Espacios libres que quedan en la semana de `referencia`, después de `desde`.
    /// Si se indica `tipo`, primero los del mismo tipo (un gimnasio se mueve a otro gimnasio).
    static func holgura(_ e: EstadoObra, semanaDe referencia: Date, desde: Date, excepto id: UUID? = nil, preferir tipo: TipoBloque? = nil) -> [Slot] {
        let lunes = referencia.lunes
        let ocupados = Set(e.bloques.filter { $0.id != id }.map { $0.inicio.inicioDelDia })
        return e.alternativas
            .map { $0.slot(enSemanaDe: lunes) }
            .filter { slot in
                slot.fecha > desde.mas(minutos: 20)
                    && !ocupados.contains(slot.fecha.inicioDelDia)
                    && !choca(e, inicio: slot.fecha, minutos: slot.minutos)
            }
            .sorted { ($0.tipo == tipo ? 0 : 1, $0.fecha) < ($1.tipo == tipo ? 0 : 1, $1.fecha) }
    }

    /// Un bloque corto para el mismo día: la forma más chica de no detenerse.
    static func puente(_ e: EstadoObra, para bloque: Bloque, barrera: TipoBarrera) -> Slot? {
        let dia = max(bloque.inicio, e.ahora).inicioDelDia
        let diaOcupado = e.bloques.contains { $0.id != bloque.id && $0.inicio.mismoDia(que: dia) }
        guard !diaOcupado else { return nil }

        let temprano = max(e.ahora.mas(minutos: 30).siguienteCuarto, dia)
        let gimnasio = Slot(fecha: dia.a(19, 30), tipo: .gimnasio, minutos: 20)
        let caminata = Slot(fecha: max(dia.a(20, 0), temprano), tipo: .caminata, minutos: 20)
        let casaTarde = Slot(fecha: max(dia.a(21, 0), temprano), tipo: .casa, minutos: 15)
        let casaSuave = Slot(fecha: max(dia.a(20, 0), temprano), tipo: .casa, minutos: 15)

        let candidatos: [Slot]
        switch barrera {
        case .reinicio, .otra: candidatos = [gimnasio, caminata, casaTarde]
        case .energia: candidatos = [caminata, casaTarde]
        case .horario: candidatos = [casaTarde, caminata]
        case .cuerpo: candidatos = [casaSuave]
        }
        return candidatos.first { slot in
            slot.fecha >= temprano
                && slot.fecha.mismoDia(que: dia)
                && slot.fecha.hora < 22
                && !choca(e, inicio: slot.fecha, minutos: slot.minutos)
        }
    }

    // MARK: - Ajuste de rendimiento

    /// Cuando una partida no rinde, se revisa el supuesto, no a la persona.
    struct AjusteDeRendimiento: Equatable {
        let desde: Ventana
        let hacia: Ventana
        /// Cuántas veces se movió ese horario desde que parte el plan: no se reinicia cada semana.
        var veces = 1
    }

    static func ventanaDelPatron(_ e: EstadoObra, para bloque: Bloque) -> Ventana? {
        e.patron.first { $0.contiene(bloque.inicio) }
    }

    /// Si un horario del patrón se movió, propone otro del mismo día y tipo.
    static func ajusteDeRendimiento(_ e: EstadoObra) -> AjusteDeRendimiento? {
        for ventana in e.patron where (e.movidasPorVentana[ventana.clave] ?? 0) > 0 && !e.ajustesResueltos.contains(ventana.clave) {
            if let alternativa = e.alternativas.first(where: { $0.dia == ventana.dia && $0.tipo == ventana.tipo && $0 != ventana }) {
                return AjusteDeRendimiento(desde: ventana, hacia: alternativa, veces: e.movidasPorVentana[ventana.clave] ?? 1)
            }
        }
        return nil
    }

    /// Cambia un horario del patrón y lleva a la nueva hora los bloques futuros que caían en él.
    static func cambiarPatron(_ e: EstadoObra, ajuste: AjusteDeRendimiento) -> EstadoObra {
        var e = e
        guard let i = e.patron.firstIndex(of: ajuste.desde) else { return e }
        e.patron[i] = ajuste.hacia
        e.alternativas.removeAll { $0 == ajuste.hacia }
        for j in e.bloques.indices where e.bloques[j].estado == .planificado
            && e.bloques[j].inicio > e.ahora
            && ajuste.desde.contiene(e.bloques[j].inicio) {
            let nueva = e.bloques[j].inicio.inicioDelDia.a(ajuste.hacia.hora, ajuste.hacia.minuto)
            guard !choca(e, inicio: nueva, minutos: ajuste.hacia.minutos) else { continue }
            e.bloques[j].inicio = nueva
            e.bloques[j].minutos = ajuste.hacia.minutos
        }
        e.ajustesResueltos.append(ajuste.desde.clave)
        return e
    }

    // MARK: - Planificación de la semana

    /// Espacios donde puede ir un bloque en su semana (patrón y alternativas), sin choques.
    static func opcionesDePlanificacion(_ e: EstadoObra, para bloque: Bloque) -> [Slot] {
        let lunes = bloque.inicio.lunes
        let ocupados = Set(e.bloques.filter { $0.id != bloque.id }.map { $0.inicio.inicioDelDia })
        let candidatos = Set((e.patron + e.alternativas).map { $0.slot(enSemanaDe: lunes) })
        return candidatos
            .filter { slot in
                slot.fecha != bloque.inicio
                    && slot.fecha > e.ahora
                    && !ocupados.contains(slot.fecha.inicioDelDia)
                    && !choca(e, inicio: slot.fecha, minutos: slot.minutos)
            }
            .sorted { $0.fecha < $1.fecha }
    }

    // MARK: - Propuestas

    static func propuestas(_ e: EstadoObra, para bloque: Bloque, lectura: Lectura) -> [Propuesta] {
        let slotPuente = puente(e, para: bloque, barrera: lectura.barrera)
        let slotHolgura = holgura(e, semanaDe: max(bloque.inicio, e.ahora), desde: e.ahora, excepto: bloque.id, preferir: bloque.tipo)
            .first { slot in slotPuente.map { !slot.fecha.mismoDia(que: $0.fecha) } ?? true }
        // Solo si ese lunes viene después del bloque: partir el lunes nunca lo adelanta. Si el trabajo
        // ocupa el lunes, parte en el primer espacio libre de esa semana y la propuesta dice ese día.
        let slotLunes = slotsDelPatron(e, desde: e.ahora.lunes.mas(dias: 7), cantidad: 1).first { $0.fecha > bloque.inicio }

        let conHolgura = slotHolgura.map { slot in
            Propuesta(
                etiqueta: "Usa la holgura",
                titulo: "\(Formato.diaRelativo(slot.fecha, ahora: e.ahora)) · \(Formato.hora(slot.fecha))",
                detalle: "\(slot.tipo.nombre), \(slot.minutos) min. Cabe en esta misma semana.",
                simbolo: "calendar.badge.plus",
                accion: .reubicar(bloque: bloque.id, slot: slot, puente: false),
                confirmacion: "Movido al \(Formato.dia(slot.fecha)). Tu plan sigue en pie."
            )
        }

        let conPuente = slotPuente.map { slot in
            Propuesta(
                etiqueta: "Bloque puente",
                titulo: "\(Formato.diaRelativo(slot.fecha, ahora: e.ahora)) · \(Formato.hora(slot.fecha))",
                detalle: detallePuente(slot),
                simbolo: slot.tipo.simbolo,
                accion: .reubicar(bloque: bloque.id, slot: slot, puente: true),
                confirmacion: "Bloque puente agendado. Corto, pero cuenta completo."
            )
        }

        let conLunes = slotLunes.map { slot in
            Propuesta(
                etiqueta: "Partir el \(Formato.dia(slot.fecha))",
                titulo: "\(Formato.diaConNumero(slot.fecha)) · \(Formato.hora(slot.fecha))",
                detalle: "Los bloques siguientes se corren un espacio, como fichas de dominó. No se suma ninguno extra.",
                simbolo: "arrow.right.to.line",
                accion: .empujar(bloque: bloque.id, fecha: slot.fecha),
                confirmacion: "Partimos el \(Formato.dia(slot.fecha)). Tu avance sigue contando."
            )
        }

        let orden: [Propuesta?]
        switch lectura.barrera {
        case .horario: orden = [conHolgura, conPuente]
        case .energia: orden = [conPuente, conHolgura]
        case .reinicio: orden = [conPuente, conHolgura, conLunes]
        case .cuerpo: orden = [conPuente, conHolgura]
        case .otra: orden = [conHolgura, conPuente, conLunes]
        }
        var opciones = orden.compactMap { $0 }
        if opciones.isEmpty, let conLunes { opciones = [conLunes] }
        return conImpacto(opciones, en: e)
    }

    static func pausas(_ e: EstadoObra) -> [Propuesta] {
        // Se cuenta desde el próximo bloque: una pausa nunca adelanta el plan ni queda vacía.
        let proximo = e.bloques.filter { $0.estado == .planificado && $0.inicio >= e.ahora.inicioDelDia }.map(\.inicio).min()
        let desde = max(e.ahora, proximo ?? e.ahora)
        let proximoLunes = desde.lunes.mas(dias: 7)
        let enDosSemanas = desde.lunes.mas(dias: 14)
        let opciones = [proximoLunes, enDosSemanas].map { hasta in
            Propuesta(
                etiqueta: "Pausa",
                titulo: "Hasta el \(Formato.dia(hasta)) \(hasta.diaDelMes)",
                detalle: "Pausas el plan sin perder tu avance. Retomas con un bloque.",
                simbolo: "pause.circle",
                accion: .pausar(hasta: hasta),
                confirmacion: "Plan en pausa. Retomas el \(Formato.dia(hasta)) \(hasta.diaDelMes)."
            )
        }
        return conImpacto(opciones, en: e)
    }

    private static func detallePuente(_ slot: Slot) -> String {
        switch slot.tipo {
        case .gimnasio: "20 minutos en el gimnasio: entrar, moverte y volver. Corto, pero cuenta completo."
        case .caminata: "20 minutos de caminata por el barrio. Corto, pero cuenta completo."
        case .casa: "15 minutos de movilidad suave en casa. Corto, pero cuenta completo."
        }
    }

    private static func conImpacto(_ propuestas: [Propuesta], en e: EstadoObra) -> [Propuesta] {
        guard let base = recepcion(e) else { return propuestas }
        return propuestas.map { propuesta in
            var propuesta = propuesta
            if let nueva = recepcion(aplicar(propuesta.accion, a: e)) {
                propuesta.impactoDias = max(0, base.dias(hasta: nueva))
            }
            return propuesta
        }
    }

    // MARK: - Cambios

    static func aplicar(_ accion: Propuesta.Accion, a e: EstadoObra) -> EstadoObra {
        switch accion {
        case let .reubicar(id, slot, puente):
            return reubicar(e, id: id, slot: slot, puente: puente)
        case let .empujar(id, fecha):
            return empujar(e, id: id, a: fecha)
        case let .pausar(hasta):
            return pausar(e, hasta: hasta)
        }
    }

    static func reubicar(_ e: EstadoObra, id: UUID, slot: Slot, puente: Bool) -> EstadoObra {
        var e = e
        guard let i = e.bloques.firstIndex(where: { $0.id == id }), e.bloques[i].estado == .planificado else { return e }
        let original = e.bloques[i]
        asignar(&e.bloques[i], slot)
        e.bloques[i].esPuente = puente
        if !original.inicio.mismoDia(que: slot.fecha) {
            e.bloques[i].origen = original.origen ?? original.inicio
        }
        return e
    }

    /// Efecto dominó: el bloque toma el espacio de destino y cada bloque siguiente
    /// toma el espacio del que viene después. La semana nunca recibe más bloques.
    static func empujar(_ e: EstadoObra, id: UUID, a destino: Date) -> EstadoObra {
        var e = e
        guard let i = e.bloques.firstIndex(where: { $0.id == id }), e.bloques[i].estado == .planificado else { return e }
        let original = e.bloques[i]
        let corte = destino.inicioDelDia
        let afectados = e.bloques.indices
            .filter { $0 != i && e.bloques[$0].estado == .planificado && e.bloques[$0].inicio >= corte }
            .sorted { e.bloques[$0].inicio < e.bloques[$1].inicio }
        let fijos = Set(e.bloques.indices
            .filter { $0 != i && !afectados.contains($0) }
            .map { e.bloques[$0].inicio.inicioDelDia })
        let nuevos = slotsDelPatron(e, desde: destino, cantidad: afectados.count + 1, diasOcupados: fijos)
        guard nuevos.count == afectados.count + 1 else { return e }

        asignar(&e.bloques[i], nuevos[0])
        e.bloques[i].origen = original.origen ?? original.inicio
        for (k, indice) in afectados.enumerated() {
            asignar(&e.bloques[indice], nuevos[k + 1])
        }
        return e
    }

    static func pausar(_ e: EstadoObra, hasta: Date) -> EstadoObra {
        var e = e
        let afectados = e.bloques.indices
            .filter { e.bloques[$0].estado == .planificado && e.bloques[$0].inicio >= e.ahora.inicioDelDia }
            .sorted { e.bloques[$0].inicio < e.bloques[$1].inicio }
        let fijos = Set(e.bloques.indices
            .filter { !afectados.contains($0) }
            .map { e.bloques[$0].inicio.inicioDelDia })
        let nuevos = slotsDelPatron(e, desde: hasta, cantidad: afectados.count, diasOcupados: fijos)
        guard nuevos.count == afectados.count else { return e }

        for (k, indice) in afectados.enumerated() {
            asignar(&e.bloques[indice], nuevos[k])
        }
        e.pausaHasta = hasta
        return e
    }

    private static func asignar(_ bloque: inout Bloque, _ slot: Slot) {
        bloque.inicio = slot.fecha
        bloque.tipo = slot.tipo
        bloque.minutos = slot.minutos
        bloque.esPuente = false
    }
}
