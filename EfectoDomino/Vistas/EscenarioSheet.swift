import SwiftUI

/// Controles para la demo, separados de la experiencia de Camila.
struct EscenarioSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    DatePicker("Ahora", selection: Binding(get: { store.ahora }, set: { store.fijarAhora($0) }))
                } header: {
                    Text("Reloj del escenario").textCase(nil)
                } footer: {
                    Text("Toda la app usa este reloj. Camila y sus datos son ficticios.")
                }

                Section {
                    ForEach(Escenario.momentos(desde: store.estado.inicioObra)) { momento in
                        Button {
                            store.fijarAhora(momento.fecha)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(momento.titulo)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(momento.detalle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Momentos de la ficha").textCase(nil)
                }

                calendarioDeLaPega

                Section {
                    Toggle("Usar solo lectura local", isOn: $store.forzarLecturaLocal)
                    LabeledContent("IA en el dispositivo", value: store.disponibilidadIA.descripcion)
                } header: {
                    Text("Lectura").textCase(nil)
                } footer: {
                    Text("El modelo de Apple corre en el iPhone: lo que escribe Camila no sale del dispositivo.")
                }

                Section {
                    Button("Reiniciar escenario", role: .destructive) {
                        store.reiniciar()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Escenario de demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    // MARK: - Calendario de la pega

    private var calendarioDeLaPega: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(estadoCalendario)
                    Text(detalleCalendario)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: store.calendarioPega == nil ? "calendar" : "calendar.badge.checkmark")
            }

            Button {
                Task { await store.conectarCalendario() }
            } label: {
                HStack {
                    Text(store.calendarioPega == nil ? "Conectar calendario" : "Volver a leer el calendario")
                    Spacer()
                    if store.conectandoCalendario { ProgressView() }
                }
            }
            .disabled(store.conectandoCalendario)

            if store.problemaCalendario == .sinPermiso {
                Button("Abrir Ajustes") {
                    if let ajustes = URL(string: UIApplication.openSettingsURLString) { openURL(ajustes) }
                }
            }

            if store.calendarioPega != nil {
                Button("Volver a la semana de ejemplo") { store.usarSemanaDeEjemplo() }
            }
        } header: {
            Text("Calendario de la pega").textCase(nil)
        } footer: {
            Text("La app lee solo el calendario «Camila · Dominó», sincronizado en el iPhone desde Ajustes. No muestra ni guarda los demás. Al cambiar la pega, el plan se arma de nuevo desde el lunes.")
        }
    }

    private var estadoCalendario: String {
        guard store.calendarioPega != nil else { return "Usando la semana de ejemplo" }
        let eventos = store.estado.pega.count
        return "Conectado · \(eventos == 1 ? "1 evento" : "\(eventos) eventos")"
    }

    private var detalleCalendario: String {
        if let calendario = store.calendarioPega {
            let cambios = Escenario.cambiosDePatron(por: store.estado.pega, desde: store.estado.inicioObra)
            guard !cambios.isEmpty else { return "De «\(calendario)». El plan los esquiva." }
            let texto = cambios.map(describir).formatted(.list(type: .and).locale(Formato.locale))
            return "De «\(calendario)». El plan los esquiva: \(texto)."
        }
        if let problema = store.problemaCalendario { return problema.texto }
        return "Ficticia: los martes y jueves llega tarde."
    }

    /// "el bloque en casa de los martes 21:15 pasa a los jueves 21:15"
    private func describir(_ cambio: (desde: Ventana, hacia: Ventana)) -> String {
        let bloque = switch cambio.desde.tipo {
        case .gimnasio: "el gimnasio"
        case .caminata: "la caminata"
        case .casa: "el bloque en casa"
        }
        let hora = Formato.hora(cambio.hacia.hora, cambio.hacia.minuto)
        var destino = cambio.hacia.dia == cambio.desde.dia ? "las \(hora)" : "\(Formato.cadaSemana(cambio.hacia.dia)) \(hora)"
        if cambio.hacia.tipo != cambio.desde.tipo { destino = "\(cambio.hacia.tipo.nombre.lowercased()) \(destino)" }
        return "\(bloque) de \(Formato.cadaSemana(cambio.desde.dia)) \(Formato.hora(cambio.desde.hora, cambio.desde.minuto)) pasa a \(destino)"
    }
}
