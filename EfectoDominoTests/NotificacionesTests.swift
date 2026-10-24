import XCTest
import UserNotifications
@testable import EfectoDomino

final class PlanDeAvisosTests: XCTestCase {
    private var activas: PreferenciasDeAvisos {
        var p = PreferenciasDeAvisos()
        p.activadas = true
        return p
    }

    func testNoHayAvisosHastaQueCamilaLosActive() {
        XCTAssertTrue(PlanDeAvisos.calcular(Prueba.semilla(), preferencias: PreferenciasDeAvisos(), ahora: Prueba.lunes).isEmpty)
    }

    func testUsaLaHoraRealAunqueElRelojDelEscenarioEsteEnOtraSemana() {
        var e = Prueba.semilla()
        e.ahora = Prueba.lunes.mas(dias: 100)
        let ahora = Prueba.fecha(dia: 1, 18, 59)
        let avisos = PlanDeAvisos.calcular(e, preferencias: activas, ahora: ahora)
        XCTAssertFalse(avisos.isEmpty)
        XCTAssertTrue(avisos.allSatisfy { $0.fecha > ahora })
        XCTAssertEqual(avisos.first?.fecha, Prueba.fecha(dia: 1, 19))
    }

    func testMoverYRegistrarUnBloqueActualizaSusAvisos() throws {
        var e = Prueba.semilla()
        let bloque = e.bloques[0]
        let ahora = Prueba.lunes
        let inicial = try XCTUnwrap(PlanDeAvisos.calcular(e, preferencias: activas, ahora: ahora).first { $0.bloque == bloque.id })
        e.bloques[0].inicio = bloque.inicio.mas(dias: 1)
        let movido = try XCTUnwrap(PlanDeAvisos.calcular(e, preferencias: activas, ahora: ahora).first { $0.bloque == bloque.id })
        XCTAssertEqual(inicial.id, movido.id)
        XCTAssertEqual(movido.fecha, inicial.fecha.mas(dias: 1))
        e.bloques[0].estado = .hecho
        XCTAssertFalse(PlanDeAvisos.calcular(e, preferencias: activas, ahora: ahora).contains { $0.bloque == bloque.id })
    }

    func testElRefuerzoExigeUnFuiConRegistroYDeshacerLoCancela() throws {
        var e = Prueba.semilla()
        let ahora = Prueba.fecha(dia: 1, 20)
        let refuerzo = RefuerzoDelDia(fecha: ahora, bloque: e.bloques[0].id)
        // Mover un bloque o aceptar un bloque puente no es entrenar.
        e.ajustes = 1
        e.bloques[0].esPuente = true
        XCTAssertFalse(PlanDeAvisos.calcular(e, preferencias: activas, refuerzo: refuerzo, ahora: ahora).contains { $0.tipo == .refuerzo })
        e.bloques[0].estado = .hecho
        e.bloques[0].registro = Registro(fecha: ahora, ayudo: [])
        let aviso = try XCTUnwrap(PlanDeAvisos.calcular(e, preferencias: activas, refuerzo: refuerzo, ahora: ahora).first { $0.tipo == .refuerzo })
        XCTAssertEqual(aviso.fecha, ahora.mas(minutos: 10))
        XCTAssertTrue(aviso.titulo.contains("Nivel 2"))
        XCTAssertTrue(aviso.texto.contains("7 fichas"))
        e.bloques[0].estado = .planificado
        e.bloques[0].registro = nil
        XCTAssertFalse(PlanDeAvisos.calcular(e, preferencias: activas, refuerzo: refuerzo, ahora: ahora).contains { $0.tipo == .refuerzo })
    }

    func testAbrirDeNuevoNoRepiteUnRefuerzoQueYaLlego() {
        var e = Prueba.semilla()
        let hora = Prueba.fecha(dia: 1, 20)
        e.bloques[0].estado = .hecho
        e.bloques[0].registro = Registro(fecha: hora, ayudo: [])
        let refuerzo = RefuerzoDelDia(fecha: hora, bloque: e.bloques[0].id)
        XCTAssertFalse(PlanDeAvisos.calcular(e, preferencias: activas, refuerzo: refuerzo, ahora: hora.mas(minutos: 11)).contains { $0.tipo == .refuerzo })
    }

    func testUnBloqueTempranoSeRecuerdaLaNocheAnterior() throws {
        let e = Prueba.semilla()
        let bloque = try XCTUnwrap(e.bloque(en: Prueba.fecha(dia: 3, 6, 30)))
        let aviso = try XCTUnwrap(PlanDeAvisos.calcular(e, preferencias: activas, ahora: Prueba.lunes).first { $0.bloque == bloque.id })
        XCTAssertEqual(aviso.fecha, Prueba.fecha(dia: 2, 20))
        XCTAssertTrue(aviso.texto.contains("miércoles 21 a las 06:30"))
    }

    func testUnRefuerzoNocturnoEsperaALaManana() throws {
        var e = Prueba.semilla()
        let hora = Prueba.fecha(dia: 1, 23)
        e.bloques[0].estado = .hecho
        e.bloques[0].registro = Registro(fecha: hora, ayudo: [])
        let r = RefuerzoDelDia(fecha: hora, bloque: e.bloques[0].id)
        let aviso = try XCTUnwrap(PlanDeAvisos.calcular(e, preferencias: activas, refuerzo: r, ahora: hora).first { $0.tipo == .refuerzo })
        XCTAssertEqual(aviso.fecha, Prueba.fecha(dia: 2, 8))
    }

    func testNoSaturaElDiaYRespetaElDescansoPersonalizado() {
        var e = Prueba.semilla()
        e.bloques = (0..<12).map { Bloque(tipo: .caminata, inicio: Prueba.fecha(dia: 1, 8).mas(minutos: $0 * 55), minutos: 15) }
        var p = activas
        p.registro = true
        p.descansoDesde = 20
        p.descansoHasta = 10
        let avisos = PlanDeAvisos.calcular(e, preferencias: p, ahora: Prueba.lunes)
        for delDia in Dictionary(grouping: avisos, by: { $0.fecha.inicioDelDia }).values {
            XCTAssertLessThanOrEqual(delDia.count, 2)
            if delDia.count == 2 { XCTAssertGreaterThanOrEqual(delDia[1].fecha.timeIntervalSince(delDia[0].fecha), 30 * 60) }
        }
        XCTAssertTrue(avisos.allSatisfy { $0.fecha.hora >= 10 && $0.fecha.hora < 20 })
    }

    func testConfirmarUnaSemanaQuitaSuInvitacion() throws {
        var e = Prueba.semilla()
        let ahora = Prueba.fecha(dia: 6, 12)
        let lunes = Prueba.lunes.mas(dias: 7)
        XCTAssertTrue(PlanDeAvisos.calcular(e, preferencias: activas, ahora: ahora).contains { $0.tipo == .semana && $0.fecha == lunes.mas(dias: -1).a(18) })
        e.semanasConfirmadas.append(lunes)
        XCTAssertFalse(PlanDeAvisos.calcular(e, preferencias: activas, ahora: ahora).contains { $0.tipo == .semana && $0.fecha == lunes.mas(dias: -1).a(18) })
    }

    func testLaAgendaMantieneUnLimiteAunqueSeAlargueElPlan() {
        var e = Prueba.semilla()
        e.bloques = (0..<100).map { Bloque(tipo: .casa, inicio: Prueba.lunes.mas(dias: $0).a(18), minutos: 15) }
        XCTAssertLessThanOrEqual(PlanDeAvisos.calcular(e, preferencias: activas, ahora: Prueba.lunes).count, 48)
    }

    func testReprogramarRespetaLosAvisosQueYaLlegaronHoy() {
        let ahora = Prueba.fecha(dia: 1, 12)
        let anteriores = [Prueba.fecha(dia: 1, 9), Prueba.fecha(dia: 1, 11)]
        let agenda = PlanDeAvisos.calcular(Prueba.semilla(), preferencias: activas, consumidos: anteriores, ahora: ahora)
        XCTAssertFalse(agenda.contains { $0.fecha.mismoDia(que: ahora) })
    }

    func testUnaPausaNoInvitaAEntrenarAntesDelRegreso() {
        var e = Prueba.semilla()
        e.pausaHasta = Prueba.lunes.mas(dias: 7)
        let agenda = PlanDeAvisos.calcular(e, preferencias: activas, ahora: Prueba.lunes)
        XCTAssertTrue(agenda.allSatisfy { $0.fecha >= e.pausaHasta! })
    }

    func testUnRefuerzoAplazadoPorDescansoNoGeneraDosReconocimientosAlDia() {
        var e = Prueba.semilla()
        let ahora = Prueba.fecha(dia: 2, 10)
        e.bloques[0].estado = .hecho
        e.bloques[0].registro = Registro(fecha: ahora, ayudo: [])
        let deAnoche = Prueba.fecha(dia: 2, 8)
        let agenda = PlanDeAvisos.calcular(e, preferencias: activas,
                                         refuerzo: RefuerzoDelDia(fecha: ahora, bloque: e.bloques[0].id),
                                         consumidos: [deAnoche], refuerzosConsumidos: [deAnoche], ahora: ahora)
        XCTAssertFalse(agenda.contains { $0.tipo == .refuerzo && $0.fecha.mismoDia(que: ahora) })
    }
}

@MainActor
final class NotificacionesTests: XCTestCase {
    private final class CentroDePrueba: CentroDeAvisos {
        var permiso: UNAuthorizationStatus = .authorized
        var solicitudes: [String: UNNotificationRequest] = [:]
        var visibles: [String] = []
        var peticionesDePermiso = 0
        var falla = false
        func estadoDelPermiso() async -> UNAuthorizationStatus { permiso }
        func pedirPermiso() async throws -> Bool { peticionesDePermiso += 1; permiso = .authorized; return true }
        func pendientes() async -> [UNNotificationRequest] { Array(solicitudes.values) }
        func entregadas() async -> [String] { visibles }
        func agregar(_ solicitud: UNNotificationRequest) async throws {
            await Task.yield()
            if falla { throw CocoaError(.fileWriteUnknown) }
            solicitudes[solicitud.identifier] = solicitud
        }
        func quitar(_ ids: [String]) { for id in ids { solicitudes.removeValue(forKey: id) } }
        func quitarEntregadas(_ ids: [String]) { visibles.removeAll { ids.contains($0) } }
        func usarDelegado(_ delegado: UNUserNotificationCenterDelegate) {}
    }

    private func crear(_ centro: CentroDePrueba) -> Notificaciones {
        let nombre = "PruebaAvisos.\(UUID())"
        let ajustes = UserDefaults(suiteName: nombre)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: nombre) }
        return Notificaciones(centro: centro, ajustes: ajustes)
    }

    private var estadoFuturo: EstadoObra {
        var e = Prueba.semilla()
        e.bloques = [Bloque(tipo: .gimnasio, inicio: Date().mas(dias: 2).a(19, 30), minutos: 45)]
        return e
    }

    func testAlAbrirNoPidePermisoYRespetaUnaDenegacion() async {
        let centro = CentroDePrueba()
        centro.permiso = .denied
        let avisos = crear(centro)
        avisos.actualizar(estadoFuturo)
        await avisos.esperarSincronizacion()
        await avisos.activar()
        XCTAssertEqual(centro.peticionesDePermiso, 0)
        XCTAssertFalse(avisos.preferencias.activadas)
        XCTAssertTrue(centro.solicitudes.isEmpty)
    }

    func testSoloActivarSolicitaPermisoYLaPruebaEstaIdentificada() async throws {
        let centro = CentroDePrueba()
        centro.permiso = .notDetermined
        let avisos = crear(centro)
        avisos.actualizar(estadoFuturo)
        await avisos.esperarSincronizacion()
        XCTAssertEqual(centro.peticionesDePermiso, 0)
        await avisos.activar()
        XCTAssertEqual(centro.peticionesDePermiso, 1)
        XCTAssertTrue(avisos.preferencias.activadas)
        XCTAssertFalse(avisos.proximos.isEmpty)
        await avisos.probar()
        let prueba = try XCTUnwrap(centro.solicitudes["domino.prueba"])
        XCTAssertEqual(prueba.content.title, "Así se ven tus avisos")
        XCTAssertEqual((prueba.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval, 5)
        XCTAssertNil(prueba.content.badge)
    }

    func testMoverCancelarYDesactivarReconciliadosSinDuplicados() async throws {
        let centro = CentroDePrueba()
        let avisos = crear(centro)
        var e = estadoFuturo
        avisos.actualizar(e)
        await avisos.activar()
        let inicial = try XCTUnwrap(avisos.proximos.first { $0.tipo == .preparacion })
        e.bloques[0].inicio = e.bloques[0].inicio.mas(dias: 1)
        avisos.actualizar(e)
        await avisos.esperarSincronizacion()
        XCTAssertEqual(avisos.proximos.first { $0.tipo == .preparacion }?.fecha, inicial.fecha.mas(dias: 1))
        XCTAssertEqual(centro.solicitudes.values.filter { $0.identifier == inicial.id }.count, 1)
        centro.visibles = [inicial.id]
        e.bloques[0].estado = .hecho
        avisos.actualizar(e)
        await avisos.esperarSincronizacion()
        XCTAssertNil(centro.solicitudes[inicial.id])
        XCTAssertTrue(centro.visibles.isEmpty)
        avisos.preferencias.activadas = false
        await avisos.esperarSincronizacion()
        XCTAssertTrue(centro.solicitudes.isEmpty)
    }

    func testLosCambiosRapidosNoDejanUnaAgendaVieja() async {
        let centro = CentroDePrueba()
        let avisos = crear(centro)
        let e = estadoFuturo
        avisos.actualizar(e)
        await avisos.activar()
        for dia in 1...12 {
            var movido = e
            movido.bloques[0].inicio = e.bloques[0].inicio.mas(dias: dia)
            avisos.actualizar(movido)
        }
        avisos.preferencias.activadas = false
        await avisos.esperarSincronizacion()
        XCTAssertTrue(centro.solicitudes.isEmpty)
        XCTAssertTrue(avisos.proximos.isEmpty)
    }

    func testUnErrorAlProgramarNoSeMuestraComoExito() async {
        let centro = CentroDePrueba()
        centro.falla = true
        let avisos = crear(centro)
        avisos.actualizar(estadoFuturo)
        await avisos.activar()
        XCTAssertNotNil(avisos.error)
        XCTAssertTrue(avisos.proximos.isEmpty)
    }

    func testLaSolicitudAbreElBloqueCorrectoSinMarcarloHecho() {
        let bloque = UUID()
        let fecha = Date().mas(dias: 2).a(18)
        let aviso = AvisoProgramado(id: "domino.ejemplo", fecha: fecha, titulo: "Tu bloque", texto: "Un momento para ti", tipo: .preparacion, bloque: bloque)
        let solicitud = Notificaciones.solicitud(aviso, sonido: false)
        XCTAssertEqual(solicitud.content.userInfo["bloque"] as? String, bloque.uuidString)
        XCTAssertEqual(solicitud.content.userInfo["tipo"] as? String, "preparacion")
        XCTAssertEqual((solicitud.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(), fecha)
        XCTAssertNil(solicitud.content.sound)
        XCTAssertNil(solicitud.content.badge)
    }
}
