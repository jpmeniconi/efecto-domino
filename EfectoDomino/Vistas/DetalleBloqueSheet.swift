import SwiftUI

/// Detalle de un bloque del programa: cuándo es, qué es, cómo está y, si se hizo, cómo le fue.
/// Si está planificado, desde aquí se registra o se ajusta con las mismas hojas de Mi plan.
struct DetalleBloqueSheet: View {
    @Environment(ObraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var tamanoTexto
    @ScaledMetric(relativeTo: .title) private var circulo: CGFloat = 64

    let id: UUID
    var alRegistrar: (Bloque) -> Void
    var alAjustar: (Bloque) -> Void

    /// Se lee del estado en vivo: si el bloque cambia, el detalle también.
    private var bloque: Bloque? { store.estado.bloques.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            Group {
                if let bloque {
                    contenido(bloque)
                } else {
                    ContentUnavailableView("Este bloque ya no está", systemImage: "calendar")
                }
            }
            .navigationTitle("Detalle del bloque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func contenido(_ bloque: Bloque) -> some View {
        ScrollViewReader { desplazamiento in
            lista(bloque)
                #if DEBUG
                .task {
                    // -seccion origen|registro|trabajo lleva el detalle a esa sección.
                    guard let seccion = UserDefaults.standard.string(forKey: "seccion") else { return }
                    try? await Task.sleep(for: .seconds(1))
                    desplazamiento.scrollTo(seccion, anchor: .top)
                }
                #endif
        }
    }

    private func lista(_ bloque: Bloque) -> some View {
        List {
            Section {
                encabezado(bloque)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))

            Section {
                LabeledContent("Fecha", value: Formato.fechaLarga(bloque.inicio))
                LabeledContent("Horario", value: "\(Formato.hora(bloque.inicio)) a \(Formato.hora(bloque.fin))")
                LabeledContent("Tipo") {
                    Text("\(Image(systemName: bloque.tipo.simbolo)) \(bloque.tipo.nombre)")
                        .foregroundStyle(bloque.tipo.color)
                }
                LabeledContent("Duración", value: "\(bloque.minutos) min")
                LabeledContent("Estado", value: Self.estado(bloque, ahora: store.ahora))
                LabeledContent("Semana", value: "\(store.numeroDeSemana(bloque.inicio.lunes)) de \(store.proyecto.semanas)")
            } header: {
                Text("Bloque").textCase(nil)
            } footer: {
                if bloque.esPuente {
                    Text("Bloque puente: corto, pero cuenta completo.")
                }
            }

            if let origen = bloque.origen {
                seccionOrigen(bloque, origen: origen)
                    .id("origen")
            }
            if bloque.estado == .hecho {
                seccionRegistro(bloque)
                    .id("registro")
            }
            seccionTrabajo(bloque)
                .id("trabajo")
        }
    }

    // MARK: - Encabezado

    private func encabezado(_ bloque: Bloque) -> some View {
        let color = bloque.tipo.color
        let hecho = bloque.estado == .hecho
        return VStack(spacing: 14) {
            // La ilustración ya dice qué es y las etiquetas cómo está; con texto muy grande vuelve el círculo.
            if tamanoTexto.isAccessibilitySize {
                Image(systemName: hecho ? (bloque.esRegreso ? "arrow.uturn.backward" : "checkmark") : bloque.tipo.simbolo)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(hecho ? Color.white : color)
                    .frame(width: circulo, height: circulo)
                    .background(hecho ? color : color.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
            } else {
                IlustracionBloque(tipo: bloque.tipo, alto: 150)
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
            }
            VStack(spacing: 4) {
                Text("\(bloque.tipo.nombre) · \(bloque.minutos) min")
                    .font(.title2.weight(.bold))
                Text("\(Formato.diaRelativo(bloque.inicio, ahora: store.ahora)) · \(Formato.hora(bloque.inicio))")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            etiquetas(bloque)
            if bloque.estado == .planificado {
                botones(bloque)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Con texto de accesibilidad, los botones se apilan en vez de cortarse.
    private var fila: AnyLayout {
        tamanoTexto.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
    }

    /// Las etiquetas van en una línea si caben enteras; si no, una bajo otra.
    private func etiquetas(_ bloque: Bloque) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips(bloque) }
            VStack(spacing: 8) { chips(bloque) }
        }
    }

    @ViewBuilder
    private func chips(_ bloque: Bloque) -> some View {
        Etiqueta(texto: Self.estado(bloque, ahora: store.ahora), simbolo: Self.simboloEstado(bloque, ahora: store.ahora))
        if bloque.esPuente {
            Etiqueta(texto: "Bloque puente", simbolo: "arrow.uturn.backward")
                .foregroundStyle(Color.accentColor)
        }
        if bloque.estado == .hecho && bloque.esRegreso {
            Etiqueta(texto: "Ficha de regreso", simbolo: "arrow.uturn.backward")
                .foregroundStyle(Color.accentColor)
        }
        if bloque.origen != nil {
            Etiqueta(texto: "Movido", simbolo: "arrow.right")
        }
    }

    private func botones(_ bloque: Bloque) -> some View {
        // Igual que en Mi plan: «Fui» se habilita desde 30 minutos antes.
        let puedeRegistrar = store.ahora >= bloque.inicio.mas(minutos: -30)
        return VStack(spacing: 8) {
            fila {
                Button {
                    alRegistrar(bloque)
                    dismiss()
                } label: {
                    Label("Fui", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(!puedeRegistrar)

                Button {
                    alAjustar(bloque)
                    dismiss()
                } label: {
                    Label("Ajustar", systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            if !puedeRegistrar {
                Text("«Fui» se activa 30 minutos antes del bloque.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }

    // MARK: - Secciones

    private func seccionOrigen(_ bloque: Bloque, origen: Date) -> some View {
        let dias = origen.dias(hasta: bloque.inicio)
        let movida = dias == 0 ? "El mismo día" : dias > 0 ? "\(Formato.dias(dias)) después" : "\(Formato.dias(-dias)) antes"
        return Section {
            LabeledContent("Estaba", value: "\(Formato.fechaLarga(origen)) · \(Formato.hora(origen))")
            LabeledContent("Ahora", value: "\(Formato.fechaLarga(bloque.inicio)) · \(Formato.hora(bloque.inicio))")
            LabeledContent("Se movió", value: movida)
        } header: {
            Text("De dónde se movió").textCase(nil)
        } footer: {
            Text(Self.explicacion(bloque, origen: origen))
        }
    }

    private func seccionRegistro(_ bloque: Bloque) -> some View {
        Section {
            if let registro = bloque.registro {
                let ayudas = Escenario.ayudas.filter(registro.ayudo.contains)
                    + registro.ayudo.filter { !Escenario.ayudas.contains($0) }
                LabeledContent("Cómo lo pasaste", value: registro.disfrute?.nombre ?? "Sin respuesta")
                LabeledContent("Espalda", value: registro.espalda?.nombre ?? "Sin respuesta")
                LabeledContent("Qué te ayudó") {
                    if ayudas.isEmpty {
                        Text("Nada marcado")
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(ayudas, id: \.self) { Text($0) }
                        }
                    }
                }
                LabeledContent("Registrado", value: "\(Formato.fechaConDia(registro.fecha)) · \(Formato.hora(registro.fecha))")
            } else {
                Text("Hecho, sin registro.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Tu registro").textCase(nil)
        } footer: {
            Text(bloque.esRegreso ? "Volviste a tu plan: ficha de regreso." : "Una ficha en pie. Queda en tu muro.")
        }
    }

    @ViewBuilder
    private func seccionTrabajo(_ bloque: Bloque) -> some View {
        let eventos = store.estado.trabajo
            .filter { $0.inicio.mismoDia(que: bloque.inicio) }
            .sorted { $0.inicio < $1.inicio }
        if !eventos.isEmpty {
            Section {
                ForEach(eventos) { evento in
                    LabeledContent(evento.titulo, value: "\(Formato.hora(evento.inicio)) a \(Formato.hora(evento.fin))")
                }
            } header: {
                Text("Ese día en el trabajo").textCase(nil)
            }
        }
    }

    // MARK: - Textos

    /// Planificado, hecho o sin registrar si su día ya pasó. Sin juicio.
    static func estado(_ bloque: Bloque, ahora: Date) -> String {
        switch bloque.estado {
        case .hecho: "Hecho"
        case .planificado: bloque.inicio < ahora.inicioDelDia ? "Sin registrar" : "Planificado"
        }
    }

    static func simboloEstado(_ bloque: Bloque, ahora: Date) -> String {
        switch bloque.estado {
        case .hecho: "checkmark.circle.fill"
        case .planificado: bloque.inicio < ahora.inicioDelDia ? "questionmark.circle" : "calendar"
        }
    }

    /// Cómo se movió, según lo que dejó el planificador en el bloque.
    static func explicacion(_ bloque: Bloque, origen: Date) -> String {
        if bloque.esPuente {
            return "Se volvió bloque puente: corto, pero cuenta completo."
        }
        if origen.lunes == bloque.inicio.lunes {
            return "Cupo en la holgura de su semana: el resto del plan no se movió."
        }
        return "Efecto dominó: los bloques siguientes se corrieron un espacio, sin sumar ninguno extra."
    }
}

/// Como `Chip`, pero su texto no se esconde dentro de una lista con letra de accesibilidad.
private struct Etiqueta: View {
    let texto: String
    let simbolo: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: simbolo)
                .foregroundStyle(Color.accentColor)
            Text(texto)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: .capsule)
        .fixedSize()
    }
}

extension Formato {
    /// "Lunes 20 de octubre"
    static func fechaLarga(_ fecha: Date) -> String {
        let mes = fecha.formatted(.dateTime.month(.wide).locale(locale))
        return "\(dia(fecha).conMayuscula) \(fecha.diaDelMes) de \(mes)"
    }
}
