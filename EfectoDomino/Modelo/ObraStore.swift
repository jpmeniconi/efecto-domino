import Foundation
import Observation

@MainActor
@Observable
final class ObraStore {
    struct Aviso: Identifiable, Equatable {
        let id = UUID()
        var texto: String
        var deshacer: Bool
    }

    private(set) var estado: EstadoObra
    private(set) var anterior: EstadoObra?
    var aviso: Aviso?
    var forzarLecturaLocal = false

    init() {
        estado = ObraStore.cargar() ?? Escenario.semilla()
        #if DEBUG
        if Depuracion.reiniciar { estado = Escenario.semilla() }
        if let indice = Depuracion.momento {
            let momentos = Escenario.momentos(desde: estado.inicioObra)
            if momentos.indices.contains(indice) { estado.ahora = momentos[indice].fecha }
        }
        #endif
    }

    // MARK: - Lecturas

    var ahora: Date { estado.ahora }
    var proyecto: Proyecto { estado.proyecto }
    var hechos: Int { estado.bloques.filter { $0.estado == .hecho }.count }
    var regresos: Int { estado.bloques.filter { $0.estado == .hecho && $0.esRegreso }.count }

    var planificados: [Bloque] {
        estado.bloques.filter { $0.estado == .planificado }.sorted { $0.inicio < $1.inicio }
    }

    var proximo: Bloque? {
        planificados.first { $0.inicio >= ahora.inicioDelDia }
    }

    /// Bloques de días anteriores de esta semana que quedaron sin registrar.
    var pendientes: [Bloque] {
        planificados.filter { $0.inicio < ahora.inicioDelDia && $0.inicio >= ahora.lunes }
    }

    var recepcion: Date? { Planificador.recepcion(estado) }

    var corrimientoRecepcion: Int {
        guard let base = estado.recepcionBase, let recepcion else { return 0 }
        return base.dias(hasta: recepcion)
    }

    var inicioPrograma: Date { ahora.lunes }

    func bloquesEnPrograma(dias: Int = 14) -> [Bloque] {
        let fin = inicioPrograma.mas(dias: dias)
        return estado.bloques
            .filter { $0.inicio >= inicioPrograma && $0.inicio < fin }
            .sorted { $0.inicio < $1.inicio }
    }

    var diasDeHolgura: [Date] {
        Planificador.holgura(estado, semanaDe: ahora, desde: ahora).map { $0.fecha.inicioDelDia }
    }

    func siguiente(despuesDe bloque: Bloque) -> Bloque? {
        planificados.first { $0.id != bloque.id && $0.inicio > bloque.inicio }
    }

    /// El fin de semana se ofrece mirar la semana siguiente: en vez de «mañana parto», un plan concreto.
    var semanaPorPlanificar: Date? {
        guard ahora.diaSemana >= 6 else { return nil }
        let lunes = ahora.lunes.mas(dias: 7)
        return estado.semanasConfirmadas.contains(lunes) ? nil : lunes
    }

    func bloques(enSemanaDe lunes: Date) -> [Bloque] {
        estado.bloques.filter { $0.inicio.lunes == lunes }.sorted { $0.inicio < $1.inicio }
    }

    func numeroDeSemana(_ lunes: Date) -> Int {
        estado.inicioObra.dias(hasta: lunes) / 7 + 1
    }

    func opcionesDePlanificacion(para bloque: Bloque) -> [Slot] {
        Planificador.opcionesDePlanificacion(estado, para: bloque)
    }

    var ajusteSugerido: Planificador.AjusteDeRendimiento? {
        Planificador.ajusteDeRendimiento(estado)
    }

    func propuestas(para bloque: Bloque, lectura: Lectura) -> [Propuesta] {
        Planificador.propuestas(estado, para: bloque, lectura: lectura)
    }

    func pausas() -> [Propuesta] {
        Planificador.pausas(estado)
    }

    // MARK: - Lectura con IA

    var disponibilidadIA: DisponibilidadIA { LectorIA.disponibilidad }

    func leer(_ texto: String, bloque: Bloque) async -> Lectura {
        if !forzarLecturaLocal, LectorIA.disponibilidad == .lista {
            let ahora = self.ahora
            do {
                return try await conLimite(segundos: 12) {
                    try await LectorIA.leer(texto: texto, bloque: bloque, ahora: ahora)
                }
            } catch {
                print("[Efecto Dominó] Lectura con IA no disponible: \(error)")
            }
        }
        return LectorLocal.leer(texto)
    }

    // MARK: - Cambios (solo con confirmación de Camila)

    func aplicar(_ propuesta: Propuesta) {
        anterior = estado
        if let id = propuesta.accion.bloque,
           let bloque = estado.bloques.first(where: { $0.id == id }),
           let ventana = Planificador.ventanaDelPatron(estado, para: bloque) {
            estado.movidasPorVentana[ventana.clave, default: 0] += 1
        }
        estado = Planificador.aplicar(propuesta.accion, a: estado)
        estado.ajustes += 1
        aviso = Aviso(texto: propuesta.confirmacion, deshacer: true)
        guardar()
    }

    /// "Fui": solo esto pone una ficha en pie. Aceptar un plan no es entrenar.
    func registrar(_ id: UUID, registro: Registro, prepararSiguiente: [String] = []) {
        guard let i = estado.bloques.firstIndex(where: { $0.id == id }) else { return }
        anterior = estado
        let bloque = estado.bloques[i]
        let veniaDeUnAtraso = bloque.origen != nil || bloque.esPuente
            || estado.bloques.contains { $0.estado == .planificado && $0.inicio < bloque.inicio }
        estado.bloques[i].estado = .hecho
        estado.bloques[i].registro = registro
        estado.bloques[i].esRegreso = veniaDeUnAtraso

        if !prepararSiguiente.isEmpty, let siguiente = siguiente(despuesDe: bloque),
           let j = estado.bloques.firstIndex(where: { $0.id == siguiente.id }) {
            let nuevos = prepararSiguiente.filter { !estado.bloques[j].preparacion.contains($0) }
            estado.bloques[j].preparacion.append(contentsOf: nuevos)
        }

        aviso = Aviso(
            texto: veniaDeUnAtraso
                ? "Volviste después de un atraso: ficha de regreso."
                : "Ficha \(hechos) en pie. Una falta no la bota.",
            deshacer: true
        )
        guardar()
    }

    func aceptarAjuste(_ ajuste: Planificador.AjusteDeRendimiento) {
        anterior = estado
        estado = Planificador.cambiarPatron(estado, ajuste: ajuste)
        aviso = Aviso(
            texto: "Listo: \(Formato.cadaSemana(ajuste.hacia.dia)) ahora son a las \(Formato.hora(ajuste.hacia.hora, ajuste.hacia.minuto)).",
            deshacer: true
        )
        guardar()
    }

    func descartarAjuste(_ ajuste: Planificador.AjusteDeRendimiento) {
        anterior = estado
        estado.ajustesResueltos.append(ajuste.desde.clave)
        guardar()
    }

    func confirmarSemana(_ lunes: Date) {
        anterior = estado
        estado.semanasConfirmadas.append(lunes)
        aviso = Aviso(texto: "Semana confirmada. El lunes no partes de cero: sigues tu plan.", deshacer: true)
        guardar()
    }

    /// Cambio hecho al planificar: no es un atraso, así que no deja fantasma.
    func moverEnPlanificacion(_ id: UUID, a slot: Slot) {
        guard let i = estado.bloques.firstIndex(where: { $0.id == id }) else { return }
        anterior = estado
        estado.bloques[i].inicio = slot.fecha
        estado.bloques[i].tipo = slot.tipo
        estado.bloques[i].minutos = slot.minutos
        guardar()
    }

    func alternarPreparacion(_ item: String, en id: UUID) {
        guard let i = estado.bloques.firstIndex(where: { $0.id == id }) else { return }
        if let j = estado.bloques[i].preparacion.firstIndex(of: item) {
            estado.bloques[i].preparacion.remove(at: j)
        } else {
            estado.bloques[i].preparacion.append(item)
        }
        guardar()
    }

    func deshacer() {
        guard let anterior else { return }
        estado = anterior
        self.anterior = nil
        aviso = nil
        guardar()
    }

    func cerrarAviso(_ id: UUID) {
        if aviso?.id == id { aviso = nil }
    }

    // MARK: - Escenario de demo

    func fijarAhora(_ fecha: Date) {
        estado.ahora = fecha
        guardar()
    }

    func reiniciar() {
        estado = Escenario.semilla()
        anterior = nil
        aviso = nil
        guardar()
    }

    // MARK: - Persistencia local

    private static var archivo: URL {
        URL.applicationSupportDirectory.appending(path: "obra.json")
    }

    private func guardar() {
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            let datos = try JSONEncoder().encode(estado)
            try datos.write(to: Self.archivo, options: .atomic)
        } catch {
            print("[Efecto Dominó] No se pudo guardar: \(error)")
        }
    }

    private static func cargar() -> EstadoObra? {
        guard let datos = try? Data(contentsOf: archivo) else { return nil }
        return try? JSONDecoder().decode(EstadoObra.self, from: datos)
    }
}
