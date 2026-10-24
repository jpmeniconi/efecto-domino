import Foundation
import Observation
import UserNotifications

@MainActor
protocol CentroDeAvisos: AnyObject {
    func estadoDelPermiso() async -> UNAuthorizationStatus
    func pedirPermiso() async throws -> Bool
    func pendientes() async -> [UNNotificationRequest]
    func entregadas() async -> [String]
    func agregar(_ solicitud: UNNotificationRequest) async throws
    func quitar(_ ids: [String])
    func quitarEntregadas(_ ids: [String])
    func usarDelegado(_ delegado: UNUserNotificationCenterDelegate)
}

@MainActor
final class CentroDeAvisosDelSistema: CentroDeAvisos {
    private let centro = UNUserNotificationCenter.current()
    func estadoDelPermiso() async -> UNAuthorizationStatus { await centro.notificationSettings().authorizationStatus }
    func pedirPermiso() async throws -> Bool { try await centro.requestAuthorization(options: [.alert, .sound]) }
    func pendientes() async -> [UNNotificationRequest] { await centro.pendingNotificationRequests() }
    func entregadas() async -> [String] { await centro.deliveredNotifications().map { $0.request.identifier } }
    func agregar(_ solicitud: UNNotificationRequest) async throws { try await centro.add(solicitud) }
    func quitar(_ ids: [String]) { centro.removePendingNotificationRequests(withIdentifiers: ids) }
    func quitarEntregadas(_ ids: [String]) { centro.removeDeliveredNotifications(withIdentifiers: ids) }
    func usarDelegado(_ delegado: UNUserNotificationCenterDelegate) { centro.delegate = delegado }
}

@MainActor
@Observable
final class Notificaciones: NSObject, UNUserNotificationCenterDelegate {
    struct Apertura: Equatable {
        let id = UUID()
        let tipo: AvisoProgramado.Tipo
        let bloque: UUID?
    }

    var preferencias: PreferenciasDeAvisos {
        didSet {
            guard preferencias != oldValue else { return }
            if let datos = try? JSONEncoder().encode(preferencias) { ajustes.set(datos, forKey: "avisos.preferencias") }
            actualizar()
        }
    }
    private(set) var permiso: UNAuthorizationStatus = .notDetermined
    private(set) var proximos: [AvisoProgramado] = []
    private(set) var error: String?
    private(set) var ocupada = false
    private(set) var pruebaProgramada = false
    var apertura: Apertura?

    @ObservationIgnored private let centro: CentroDeAvisos
    @ObservationIgnored private let ajustes: UserDefaults
    @ObservationIgnored private var estado: EstadoObra?
    @ObservationIgnored private var refuerzo: RefuerzoDelDia?
    @ObservationIgnored private var tarea: Task<Void, Never>?
    @ObservationIgnored private var ultimaPrueba: Date?
    /// Reservas ya vencidas cuentan aunque iOS las haya entregado con la app cerrada.
    @ObservationIgnored private var reservas: [ReservaDeAviso]

    private struct ReservaDeAviso: Codable {
        let id: String
        let fecha: Date
    }

    init(centro: CentroDeAvisos? = nil, ajustes: UserDefaults = .standard) {
        self.centro = centro ?? CentroDeAvisosDelSistema()
        self.ajustes = ajustes
        preferencias = ajustes.data(forKey: "avisos.preferencias")
            .flatMap { try? JSONDecoder().decode(PreferenciasDeAvisos.self, from: $0) } ?? PreferenciasDeAvisos()
        refuerzo = ajustes.data(forKey: "avisos.refuerzo")
            .flatMap { try? JSONDecoder().decode(RefuerzoDelDia.self, from: $0) }
        reservas = ajustes.data(forKey: "avisos.reservas")
            .flatMap { try? JSONDecoder().decode([ReservaDeAviso].self, from: $0) } ?? []
        super.init()
        self.centro.usarDelegado(self)
    }

    var permitidas: Bool { permiso == .authorized || permiso == .provisional || permiso == .ephemeral }

    /// El permiso aparece después de tocar «Activar», nunca al abrir la app.
    func activar() async {
        guard !ocupada else { return }
        ocupada = true
        defer { ocupada = false }
        error = nil
        do {
            permiso = await centro.estadoDelPermiso()
            if permiso == .notDetermined { _ = try await centro.pedirPermiso() }
            permiso = await centro.estadoDelPermiso()
            if permitidas { preferencias.activadas = true }
            actualizar()
            await tarea?.value
        } catch {
            self.error = "No se pudieron activar los avisos. Puedes volver a intentarlo."
        }
    }

    func actualizar(_ estado: EstadoObra? = nil) {
        if let estado { self.estado = estado }
        // Serializa cambios rápidos: una agenda vieja nunca agrega avisos después de la nueva.
        let anterior = tarea
        anterior?.cancel()
        tarea = Task { [weak self] in
            await anterior?.value
            guard !Task.isCancelled, let self else { return }
            await sincronizar()
        }
    }

    func registrar(_ bloque: UUID, ahora: Date = Date()) {
        let fecha = refuerzo?.fecha.mismoDia(que: ahora) == true ? refuerzo!.fecha : ahora
        refuerzo = RefuerzoDelDia(fecha: fecha, bloque: bloque)
        if let datos = try? JSONEncoder().encode(refuerzo) { ajustes.set(datos, forKey: "avisos.refuerzo") }
    }

    /// También se usa al deshacer: elimina el refuerzo del registro revertido.
    func limpiarRefuerzo() {
        refuerzo = nil
        ajustes.removeObject(forKey: "avisos.refuerzo")
    }

    func esperarSincronizacion() async { await tarea?.value }

    private func sincronizar() async {
        permiso = await centro.estadoDelPermiso()
        guard !Task.isCancelled else { return }
        let pendientes = await centro.pendientes()
        guard !Task.isCancelled else { return }
        let entregadas = await centro.entregadas()
        guard !Task.isCancelled else { return }
        let anteriores = pendientes.map(\.identifier).filter { $0.hasPrefix(PlanDeAvisos.prefijo) && $0 != "domino.prueba" }
        let entregadasDelPlan = entregadas.filter { $0.hasPrefix(PlanDeAvisos.prefijo) && $0 != "domino.prueba" }
        centro.quitar(anteriores)
        let ahora = Date()
        reservas = reservas.filter { $0.fecha <= ahora && $0.fecha.mismoDia(que: ahora) }
        guardarReservas()
        if !preferencias.activadas || !permitidas {
            centro.quitar(["domino.prueba"])
            centro.quitarEntregadas(entregadasDelPlan + ["domino.prueba"])
            proximos = []
            pruebaProgramada = false
            return
        }
        guard let estado else { return }
        error = nil
        let agenda = PlanDeAvisos.calcular(
            estado, preferencias: preferencias, refuerzo: refuerzo,
            consumidos: reservas.map(\.fecha),
            refuerzosConsumidos: reservas.filter { $0.id.hasPrefix("domino.refuerzo.") }.map(\.fecha), ahora: ahora
        )
        var agregados: [AvisoProgramado] = []
        for aviso in agenda {
            guard !Task.isCancelled else { return }
            guard aviso.fecha > Date() else { continue }
            do {
                try await centro.agregar(Self.solicitud(aviso, sonido: preferencias.sonido))
                agregados.append(aviso)
                reservas.append(ReservaDeAviso(id: aviso.id, fecha: aviso.fecha))
                guardarReservas()
            } catch {
                self.error = "Algunos avisos no se pudieron programar. Vuelve a abrir esta hoja para intentarlo otra vez."
            }
        }
        guard !Task.isCancelled else { return }
        proximos = agregados
        // Los avisos de un bloque hecho o movido dejan de ofrecer su horario anterior.
        let vigentes = Set(agenda.map(\.id))
        centro.quitarEntregadas(entregadasDelPlan.filter { !vigentes.contains($0) })
    }

    private func guardarReservas() {
        if let datos = try? JSONEncoder().encode(reservas) { ajustes.set(datos, forKey: "avisos.reservas") }
    }

    static func solicitud(_ aviso: AvisoProgramado, sonido: Bool) -> UNNotificationRequest {
        let contenido = UNMutableNotificationContent()
        contenido.title = aviso.titulo
        contenido.body = aviso.texto
        contenido.threadIdentifier = "domino.plan"
        contenido.sound = sonido ? .default : nil
        contenido.userInfo = ["tipo": aviso.tipo.rawValue]
        if let bloque = aviso.bloque { contenido.userInfo["bloque"] = bloque.uuidString }
        let fecha = Calendar.obra.dateComponents([.timeZone, .year, .month, .day, .hour, .minute, .second], from: aviso.fecha)
        return UNNotificationRequest(identifier: aviso.id, content: contenido, trigger: UNCalendarNotificationTrigger(dateMatching: fecha, repeats: false))
    }

    func probar() async {
        guard permitidas, preferencias.activadas else { return }
        guard ultimaPrueba.map({ Date().timeIntervalSince($0) >= 10 }) ?? true else { return }
        let contenido = UNMutableNotificationContent()
        contenido.title = "Así se ven tus avisos"
        contenido.body = "Esta es una prueba. Tus avisos acompañan el plan que tú eliges."
        contenido.sound = preferencias.sonido ? .default : nil
        contenido.userInfo = ["tipo": AvisoProgramado.Tipo.semana.rawValue]
        do {
            try await centro.agregar(UNNotificationRequest(identifier: "domino.prueba", content: contenido, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            ultimaPrueba = Date()
            pruebaProgramada = true
        } catch { self.error = "No se pudo enviar la prueba. Inténtalo otra vez." }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // El registro ya se reconoce dentro de la app; la prueba sí se muestra para poder revisarla.
        completionHandler(notification.request.identifier == "domino.prueba" ? [.banner, .sound] : [])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let datos = response.notification.request.content.userInfo
        let tipo = (datos["tipo"] as? String).flatMap(AvisoProgramado.Tipo.init(rawValue:))
        let bloque = (datos["bloque"] as? String).flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            if let tipo { self.apertura = Apertura(tipo: tipo, bloque: bloque) }
            completionHandler()
        }
    }
}
