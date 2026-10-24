import SwiftUI
import UserNotifications

struct NotificacionesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var abrirURL
    @Environment(\.scenePhase) private var fase
    @Bindable var notificaciones: Notificaciones

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Un aviso para lo que tú elegiste", systemImage: "bell.badge")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                    Text("Prepara tu próximo bloque y reconoce lo que ya hiciste. Tú eliges qué recibir.")
                        .foregroundStyle(.secondary)
                    Toggle("Recibir avisos", isOn: Binding(
                        get: { notificaciones.preferencias.activadas && notificaciones.permitidas },
                        set: { activar in
                            if activar { Task { await notificaciones.activar() } }
                            else { notificaciones.preferencias.activadas = false }
                        }
                    ))
                    .disabled(notificaciones.ocupada)
                    if notificaciones.ocupada { ProgressView("Activando avisos…") }
                    if notificaciones.permiso == .denied {
                        Text("Los avisos están desactivados en el iPhone. Puedes permitirlos en Ajustes.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Abrir Ajustes del iPhone") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                        }
                    }
                } footer: {
                    Text("Acompañan tus decisiones. Como máximo dos al día, separados por al menos media hora.")
                }

                Section {
                    Toggle(isOn: $notificaciones.preferencias.preparacion) {
                        opcion("Antes de tu bloque", detalle: "Un momento para dejar lo que necesitas a mano.", simbolo: "bag")
                    }
                    if notificaciones.preferencias.preparacion {
                        Picker("Con cuánto tiempo", selection: $notificaciones.preferencias.minutosAntes) {
                            Text("15 minutos").tag(15)
                            Text("30 minutos").tag(30)
                            Text("1 hora").tag(60)
                        }
                    }
                    Toggle(isOn: $notificaciones.preferencias.registro) {
                        opcion("Guardar tu experiencia", detalle: "Una invitación a registrar el bloque, 20 minutos después de que termine.", simbolo: "checkmark.circle")
                    }
                    Toggle(isOn: $notificaciones.preferencias.refuerzo) {
                        opcion("Reconocer tu avance", detalle: "Después de guardar «Fui», recuerda tu ficha de regreso, tu nivel o el avance de tu muro. Un reconocimiento al día.", simbolo: "rectangle.split.1x2")
                    }
                    Toggle(isOn: $notificaciones.preferencias.semana) {
                        opcion("Dejar lista tu semana", detalle: "El domingo a las 18:00, si todavía no la confirmaste.", simbolo: "calendar")
                    }
                } header: {
                    Text("Qué quieres recibir").textCase(nil)
                }

                Section {
                    Picker("Descansar desde", selection: $notificaciones.preferencias.descansoDesde) {
                        ForEach(20...23, id: \.self) { Text(Formato.hora($0, 0)).tag($0) }
                    }
                    Picker("Hasta", selection: $notificaciones.preferencias.descansoHasta) {
                        ForEach(6...10, id: \.self) { Text(Formato.hora($0, 0)).tag($0) }
                    }
                    Toggle("Con sonido", isOn: $notificaciones.preferencias.sonido)
                } header: {
                    Text("Tu horario de descanso").textCase(nil)
                } footer: {
                    Text("Para un bloque temprano, el recordatorio llega la noche anterior, dos horas antes de tu descanso. Los reconocimientos nocturnos esperan a la mañana. Los avisos usan la hora del iPhone.")
                }

                Section {
                    if notificaciones.proximos.isEmpty {
                        Text(notificaciones.preferencias.activadas && notificaciones.permitidas
                             ? "No hay avisos pendientes para las fechas de tu plan."
                             : "Al activarlos, aquí verás cuándo llega cada aviso.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(notificaciones.proximos.prefix(5)) { aviso in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(aviso.titulo).font(.subheadline.weight(.semibold))
                            Text("\(Formato.fechaConDia(aviso.fecha)) · \(Formato.hora(aviso.fecha))")
                                .font(.caption).foregroundStyle(Color.accentColor)
                            Text(aviso.texto).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Próximos avisos").textCase(nil)
                } footer: {
                    Text("Si mueves un bloque, sus avisos cambian con él. Si lo registras, se cancelan sus recordatorios.")
                }

                if notificaciones.permitidas && notificaciones.preferencias.activadas {
                    Section {
                        Button("Probar un aviso", systemImage: "bell") { Task { await notificaciones.probar() } }
                        if notificaciones.pruebaProgramada {
                            Text("La prueba se muestra en cinco segundos, también con esta hoja abierta.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("La prueba está marcada como ejemplo y no registra ningún bloque.")
                    }
                }
                if let error = notificaciones.error {
                    Section { Text(error).foregroundStyle(.secondary) }
                }
            }
            .tint(Color.accentColor)
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .task {
                notificaciones.actualizar()
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "avisoDePrueba") {
                    await notificaciones.esperarSincronizacion()
                    await notificaciones.probar()
                }
                #endif
            }
            .onChange(of: fase) { _, nueva in
                if nueva == .active { notificaciones.actualizar() }
            }
        }
    }

    private func opcion(_ titulo: String, detalle: String, simbolo: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo)
                Text(detalle).font(.caption).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: simbolo).foregroundStyle(Color.accentColor) }
    }
}
