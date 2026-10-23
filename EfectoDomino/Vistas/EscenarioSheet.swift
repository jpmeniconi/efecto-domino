import SwiftUI

/// Controles para la demo, separados de la experiencia de Camila.
struct EscenarioSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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
}
