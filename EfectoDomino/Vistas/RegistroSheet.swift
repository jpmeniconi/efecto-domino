import SwiftUI

/// Checklist después de entrenar: qué funcionó y dejar listo el próximo bloque.
struct RegistroSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var tamanoTexto

    let bloque: Bloque
    var alGuardar: (Registro, [String]) -> Void

    @State private var disfrute: Disfrute?
    @State private var espalda: Sensacion?
    @State private var ayudo: Set<String> = []
    @State private var preparar: Set<String> = []
    @State private var foto: String?
    @State private var eligiendoFoto = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    encabezado
                }
                .listRowInsets(EdgeInsets())
                Section {
                    filaFoto
                } footer: {
                    Text("Queda en «Tu avance» con esta ficha.")
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
            .sheet(isPresented: $eligiendoFoto) {
                ElegirFotoSheet(elegida: foto) { elegida in
                    withAnimation(.snappy) { foto = elegida }
                }
            }
            #if DEBUG
            .task {
                if let prueba = DepuracionFotos.fotoDePrueba { foto = prueba }
                if DepuracionFotos.elegirFoto { eligiendoFoto = true }
                guard Depuracion.registrar else { return }
                try? await Task.sleep(for: .seconds(1))
                alGuardar(Registro(fecha: store.ahora, disfrute: .bien, espalda: .mejor, ayudo: ["Era corto"], foto: foto), [])
                dismiss()
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") {
                        let registro = Registro(fecha: store.ahora, disfrute: disfrute, espalda: espalda, ayudo: Array(ayudo), foto: foto)
                        alGuardar(registro, Array(preparar))
                        dismiss()
                    }
                }
            }
        }
    }

    private var encabezado: some View {
        VStack(spacing: 0) {
            IlustracionBloque(tipo: bloque.tipo)
            VStack(spacing: 4) {
                Text("Ficha \(store.hechos + 1) de \(store.proyecto.meta)")
                    .font(.title2.weight(.bold))
                Text("\(bloque.tipo.nombre) · \(bloque.minutos) min" + (bloque.esPuente ? " · bloque puente" : ""))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal)
        }
        .accessibilityElement(children: .combine)
    }

    /// Sin foto, una fila para agregarla. Con foto, la miniatura para cambiarla y la opción de quitarla.
    @ViewBuilder
    private var filaFoto: some View {
        if let foto {
            // Con texto muy grande, la foto arriba y el texto abajo.
            let disposicion = tamanoTexto.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 14))
            Button {
                eligiendoFoto = true
            } label: {
                disposicion {
                    ImagenDeFicha(foto: foto)
                        .scaledToFill()
                        .frame(width: 56, height: 84)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    Text("Cambiar foto")
                        .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Foto de este bloque: \(HistorialFotos.descripcion(de: foto, tipo: bloque.tipo))")
            .accessibilityHint("Cambia la foto")
            Button("Quitar foto", systemImage: "trash", role: .destructive) {
                withAnimation(.snappy) { self.foto = nil }
            }
        } else {
            Button("Agregar foto", systemImage: "photo.badge.plus") { eligiendoFoto = true }
        }
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
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(marcada ? .isSelected : [])
    }
}
