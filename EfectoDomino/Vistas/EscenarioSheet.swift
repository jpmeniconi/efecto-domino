import SwiftUI

/// Controles para la demo, separados de la experiencia de Camila.
struct EscenarioSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmandoReinicio = false

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

                calendarioDelTrabajo

                Section {
                    Toggle("Usar solo lectura local", isOn: $store.forzarLecturaLocal)
                    LabeledContent("Modelo del iPhone", value: store.disponibilidadIA.descripcion)
                } header: {
                    Text("Lectura").textCase(nil)
                } footer: {
                    Text("El modelo de Apple corre en el iPhone: lo que escribe Camila no sale del dispositivo.")
                }

                Section {
                    Button("Reiniciar escenario", role: .destructive) {
                        confirmandoReinicio = true
                    }
                    .confirmarReinicio($confirmandoReinicio, estado: store.estado) {
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

    // MARK: - Calendario del trabajo

    private var calendarioDelTrabajo: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(estadoCalendario)
                    Text(detalleCalendario)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: store.calendarioTrabajo == nil ? "calendar" : "calendar.badge.checkmark")
            }

            Button {
                Task { await store.conectarCalendario() }
            } label: {
                HStack {
                    Text(store.calendarioTrabajo == nil ? "Conectar calendario" : "Volver a leer el calendario")
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

            if store.calendarioTrabajo != nil {
                Button("Volver a la semana de ejemplo") { store.usarSemanaDeEjemplo() }
            }
        } header: {
            Text("Calendario del trabajo").textCase(nil)
        } footer: {
            Text("La app lee solo el calendario «Camila · Dominó», sincronizado en el iPhone desde Ajustes. No muestra ni guarda los demás. Al conectarlo o volver a leerlo, el plan se arma de nuevo desde el lunes.")
        }
    }

    private var estadoCalendario: String {
        guard store.calendarioTrabajo != nil else { return "Usando la semana de ejemplo" }
        let eventos = store.estado.trabajo.count
        return "Conectado · \(eventos == 1 ? "1 evento" : "\(eventos) eventos")"
    }

    private var detalleCalendario: String {
        if let calendario = store.calendarioTrabajo {
            let cambios = Escenario.cambiosDePatron(por: store.estado.trabajo, desde: store.estado.inicioObra)
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

/// Reiniciar borra lo hecho en la demo: se pregunta antes, en el menú de Mi plan y en el escenario.
enum Reinicio {
    static let titulo = "¿Reiniciar el escenario?"

    static func mensaje(_ e: EstadoObra) -> String {
        let fichas = e.bloques.fichasEnPie
        var partes: [String] = []
        if fichas > 0 { partes.append(fichas == 1 ? "1 ficha en pie" : "\(fichas) fichas en pie") }
        if e.ajustes > 0 { partes.append(e.ajustes == 1 ? "1 ajuste" : "\(e.ajustes) ajustes") }
        let plan = "el plan se arma de nuevo desde el lunes de esta semana. No se puede deshacer."
        switch partes.count {
        case 0: return "El plan se arma de nuevo desde el lunes de esta semana. No se puede deshacer."
        case 1: return "\(fichas + e.ajustes == 1 ? "Se borra" : "Se borran") \(partes[0]) y \(plan)"
        default: return "Se borran \(partes[0]) y \(partes[1]), y \(plan)"
        }
    }
}

extension View {
    func confirmarReinicio(_ presentado: Binding<Bool>, estado: EstadoObra, alConfirmar: @escaping () -> Void) -> some View {
        confirmationDialog(Reinicio.titulo, isPresented: presentado, titleVisibility: .visible) {
            Button("Reiniciar escenario", role: .destructive, action: alConfirmar)
        } message: {
            Text(Reinicio.mensaje(estado))
        }
    }
}
