import SwiftUI

/// Camila cuenta qué pasó; la IA lee la barrera y el planificador propone opciones.
/// Nada cambia hasta que ella confirma.
struct AjustarSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bloque: Bloque
    var alConfirmar: (Propuesta) -> Void

    @State private var texto = ""
    @State private var leyendo = false
    @State private var lectura: Lectura?
    @State private var propuestas: [Propuesta] = []
    @State private var pausas: [Propuesta] = []
    @State private var elegida: UUID?
    @State private var verPausas = false
    @FocusState private var escribiendo: Bool

    private let atajos = ["Se alargó la reunión", "Estoy agotada", "Ya perdí la semana", "Me duele la espalda"]

    private var propuestaElegida: Propuesta? {
        (propuestas + pausas).first { $0.id == elegida }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { desplazamiento in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        resumen
                        pregunta
                        if leyendo {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Leyendo lo que pasó…")
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.opacity)
                        }
                        if let lectura {
                            LecturaVista(lectura: lectura)
                                .id("lectura")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            opciones
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                    .animation(.snappy, value: lectura)
                    .animation(.snappy, value: leyendo)
                }
                .onChange(of: lectura) { _, nueva in
                    guard nueva != nil else { return }
                    withAnimation(.smooth(duration: 0.5).delay(0.15)) {
                        desplazamiento.scrollTo("lectura", anchor: .top)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ajustar bloque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let propuesta = propuestaElegida {
                    Button {
                        alConfirmar(propuesta)
                        dismiss()
                    } label: {
                        Text("Confirmar ajuste")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
        .onChange(of: verPausas) { _, abiertas in
            if abiertas && pausas.isEmpty { pausas = store.pausas() }
        }
        .task { LectorIA.precalentar() }
        #if DEBUG
        .task {
            guard let textoDePrueba = Depuracion.texto else { return }
            texto = textoDePrueba
            await leer()
            if let indice = Depuracion.aplicar, propuestas.indices.contains(indice) {
                try? await Task.sleep(for: .seconds(1))
                alConfirmar(propuestas[indice])
                dismiss()
            }
        }
        #endif
    }

    private var resumen: some View {
        HStack(spacing: 14) {
            Image(systemName: bloque.tipo.simbolo)
                .font(.title2)
                .foregroundStyle(bloque.tipo.color)
                .frame(width: 48, height: 48)
                .background(bloque.tipo.color.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(bloque.tipo.nombre) · \(bloque.minutos) min")
                    .font(.headline)
                Text("\(Formato.diaRelativo(bloque.inicio, ahora: store.ahora)) · \(Formato.hora(bloque.inicio))")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var pregunta: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Qué pasó?")
                .font(.title3.weight(.semibold))
            TextField("Escríbelo como se lo contarías a alguien", text: $texto, axis: .vertical)
                .lineLimit(2...4)
                .focused($escribiendo)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(atajos, id: \.self) { atajo in
                        Button(atajo) {
                            texto = atajo
                            Task { await leer() }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
            }
            .scrollClipDisabled()
            Button {
                Task { await leer() }
            } label: {
                Text("Ver opciones")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || leyendo)
        }
    }

    private var opciones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Opciones")
                .font(.title3.weight(.semibold))
            ForEach(propuestas) { propuesta in
                TarjetaPropuesta(
                    propuesta: propuesta,
                    elegida: elegida == propuesta.id,
                    sugerida: propuesta.id == propuestas.first?.id
                ) { elegida = propuesta.id }
            }
            DisclosureGroup("Ninguna me sirve", isExpanded: $verPausas) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Puedes pausar el plan sin perder tu avance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(pausas) { propuesta in
                        TarjetaPropuesta(propuesta: propuesta, elegida: elegida == propuesta.id, sugerida: false) {
                            elegida = propuesta.id
                        }
                    }
                }
                .padding(.top, 10)
            }
            .tint(.secondary)
            .padding(.top, 4)
        }
    }

    private func leer() async {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty, !leyendo else { return }
        escribiendo = false
        leyendo = true
        lectura = nil
        propuestas = []
        elegida = nil
        let resultado = await store.leer(limpio, bloque: bloque)
        let opciones = store.propuestas(para: bloque, lectura: resultado)
        lectura = resultado
        propuestas = opciones
        elegida = opciones.first?.id
        leyendo = false
    }
}

struct LecturaVista: View {
    let lectura: Lectura

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(lectura.barrera.nombre, systemImage: lectura.barrera.simbolo)
                .font(.subheadline.weight(.semibold))
            Text(lectura.resumen)
                .fixedSize(horizontal: false, vertical: true)
            if lectura.barrera == .cuerpo {
                Text("Si el dolor sigue o es intenso, consulta a un profesional de salud.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 18))
    }
}

struct TarjetaPropuesta: View {
    let propuesta: Propuesta
    let elegida: Bool
    let sugerida: Bool
    var alElegir: () -> Void

    var body: some View {
        Button(action: alElegir) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: propuesta.simbolo)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(propuesta.etiqueta)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if sugerida {
                            Text("Sugerida")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12), in: .capsule)
                        }
                    }
                    Text(propuesta.titulo)
                        .font(.headline)
                    Text(propuesta.detalle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(propuesta.impactoTexto, systemImage: propuesta.impactoDias == 0 ? "checkmark.seal.fill" : "arrow.right.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(propuesta.impactoDias == 0 ? Color.green : Color.secondary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: elegida ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(elegida ? Color.accentColor : Color.secondary.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(elegida ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: elegida)
    }
}
