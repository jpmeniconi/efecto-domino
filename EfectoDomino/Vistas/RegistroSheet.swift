import SwiftUI

/// Checklist después de entrenar: qué funcionó y dejar listo el próximo bloque.
struct RegistroSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bloque: Bloque
    var alGuardar: (Registro, [String]) -> Void

    @State private var disfrute: Disfrute?
    @State private var espalda: Sensacion?
    @State private var ayudo: Set<String> = []
    @State private var preparar: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    encabezado
                }
                Section {
                    Picker("Cómo lo pasaste", selection: $disfrute) {
                        ForEach(Disfrute.allCases) { opcion in
                            Text(opcion.nombre).tag(Optional(opcion))
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("¿Cómo lo pasaste?").textCase(nil)
                }
                Section {
                    Picker("Espalda", selection: $espalda) {
                        ForEach(Sensacion.allCases) { opcion in
                            Text(opcion.nombre).tag(Optional(opcion))
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("¿Cómo quedó la espalda?").textCase(nil)
                }
                Section {
                    ForEach(Escenario.ayudas, id: \.self) { item in
                        filaMarcable(item, marcada: ayudo.contains(item)) {
                            if ayudo.contains(item) { ayudo.remove(item) } else { ayudo.insert(item) }
                        }
                    }
                } header: {
                    Text("¿Qué te ayudó a ir?").textCase(nil)
                } footer: {
                    Text("Así el plan aprende qué te funciona.")
                }
                if let siguiente = store.siguiente(despuesDe: bloque) {
                    Section {
                        ForEach(Escenario.preparacion(para: siguiente.tipo), id: \.self) { item in
                            filaMarcable(item, marcada: preparar.contains(item)) {
                                if preparar.contains(item) { preparar.remove(item) } else { preparar.insert(item) }
                            }
                        }
                    } header: {
                        Text("Deja listo el próximo").textCase(nil)
                    } footer: {
                        Text("\(Formato.diaRelativo(siguiente.inicio, ahora: store.ahora)) · \(Formato.hora(siguiente.inicio)) · \(siguiente.tipo.nombre), \(siguiente.minutos) min")
                    }
                }
            }
            .navigationTitle("Registrar bloque")
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
            .task {
                guard Depuracion.registrar else { return }
                try? await Task.sleep(for: .seconds(1))
                alGuardar(Registro(fecha: store.ahora, disfrute: .bien, espalda: .mejor, ayudo: ["Era corto"]), [])
                dismiss()
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") {
                        let registro = Registro(fecha: store.ahora, disfrute: disfrute, espalda: espalda, ayudo: Array(ayudo))
                        alGuardar(registro, Array(preparar))
                        dismiss()
                    }
                }
            }
        }
    }

    private var encabezado: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.split.1x2.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            Text("Ficha \(store.hechos + 1) de \(store.proyecto.meta)")
                .font(.title2.weight(.bold))
            Text("\(bloque.tipo.nombre) · \(bloque.minutos) min" + (bloque.esPuente ? " · bloque puente" : ""))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func filaMarcable(_ texto: String, marcada: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text(texto)
                    .foregroundStyle(.primary)
                Spacer()
                if marcada {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
