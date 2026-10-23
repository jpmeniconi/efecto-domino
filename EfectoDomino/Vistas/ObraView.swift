import SwiftUI

struct ObraView: View {
    @Environment(ObraStore.self) private var store

    @State private var ajustando: Bloque?
    @State private var registrando: Bloque?
    @State private var propuestaPendiente: Propuesta?
    @State private var registroPendiente: RegistroPendiente?
    @State private var mostrandoEscenario = false

    private struct RegistroPendiente {
        let id: UUID
        let registro: Registro
        let prepararSiguiente: [String]
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { desplazamiento in
                ScrollView {
                    contenido
                }
                #if DEBUG
                .onAppear { abrirDesdeDepuracion(desplazamiento) }
                #endif
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mi obra")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: ReporteDeAvance(
                            bloques: store.estado.bloques,
                            proyecto: store.proyecto,
                            inicioObra: store.estado.inicioObra,
                            ahora: store.ahora
                        ),
                        preview: SharePreview("Mi avance de obra", image: Image(systemName: "square.stack.3d.up.fill"))
                    ) {
                        Label("Compartir avance", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Escenario de demo", systemImage: "slider.horizontal.3") { mostrandoEscenario = true }
                        Button("Reiniciar escenario", systemImage: "arrow.counterclockwise", role: .destructive) {
                            store.reiniciar()
                        }
                    } label: {
                        Label("Opciones", systemImage: "ellipsis")
                    }
                }
            }
            .sheet(item: $ajustando, onDismiss: aplicarPropuesta) { bloque in
                AjustarSheet(bloque: bloque) { propuestaPendiente = $0 }
            }
            .sheet(item: $registrando, onDismiss: aplicarRegistro) { bloque in
                RegistroSheet(bloque: bloque) { registro, preparar in
                    registroPendiente = RegistroPendiente(id: bloque.id, registro: registro, prepararSiguiente: preparar)
                }
            }
            .sheet(isPresented: $mostrandoEscenario) {
                EscenarioSheet()
            }
            .overlay(alignment: .bottom) { avisoFlotante }
            .animation(.spring(duration: 0.4), value: store.aviso)
            .sensoryFeedback(.success, trigger: store.hechos)
        }
    }

    private var contenido: some View {
        VStack(spacing: 16) {
            relojEscenario
            if let lunes = store.semanaPorPlanificar {
                PlanSemanaCard(
                    lunes: lunes,
                    bloques: store.bloques(enSemanaDe: lunes),
                    numeroSemana: store.numeroDeSemana(lunes),
                    semanas: store.proyecto.semanas,
                    hechos: store.hechos,
                    opciones: { store.opcionesDePlanificacion(para: $0) },
                    alMover: { bloque, slot in store.moverEnPlanificacion(bloque.id, a: slot) },
                    alConfirmar: { store.confirmarSemana(lunes) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            AvanceCard(
                bloques: store.estado.bloques,
                proyecto: store.proyecto,
                inicioObra: store.estado.inicioObra,
                ahora: store.ahora,
                recepcion: store.recepcion,
                corrimiento: store.corrimientoRecepcion,
                ajustes: store.estado.ajustes
            )
            if let ajuste = store.ajusteSugerido {
                AjusteCard(
                    ajuste: ajuste,
                    alAceptar: { store.aceptarAjuste(ajuste) },
                    alDescartar: { store.descartarAjuste(ajuste) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            ForEach(store.pendientes) { bloque in
                PendienteCard(
                    bloque: bloque,
                    alRegistrar: { registrando = bloque },
                    alAjustar: { ajustando = bloque }
                )
            }
            if let bloque = store.proximo {
                ProximoBloqueCard(
                    bloque: bloque,
                    ahora: store.ahora,
                    alAjustar: { ajustando = bloque },
                    alRegistrar: { registrando = bloque },
                    alPreparar: { store.alternarPreparacion($0, en: bloque.id) }
                )
            }
            GanttCard(
                bloques: store.bloquesEnPrograma(),
                pega: store.estado.pega,
                inicio: store.inicioPrograma,
                ahora: store.ahora,
                diasHolgura: store.diasDeHolgura
            )
            .id("gantt")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 110)
        .animation(.snappy, value: store.ajusteSugerido)
        .animation(.snappy, value: store.semanaPorPlanificar)
    }

    #if DEBUG
    private func abrirDesdeDepuracion(_ desplazamiento: ScrollViewProxy) {
        if let foco = Depuracion.foco { desplazamiento.scrollTo(foco, anchor: .top) }
        switch Depuracion.abrir {
        case "ajustar": ajustando = store.proximo
        case "registrar": registrando = store.proximo
        case "escenario": mostrandoEscenario = true
        default: break
        }
    }
    #endif

    private var relojEscenario: some View {
        Button {
            mostrandoEscenario = true
        } label: {
            Label("Escenario ficticio · \(Formato.fechaConDia(store.ahora)) · \(Formato.hora(store.ahora))", systemImage: "clock")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06), in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHint("Abre los controles del escenario de demo")
    }

    @ViewBuilder
    private var avisoFlotante: some View {
        if let aviso = store.aviso {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(aviso.texto)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if aviso.deshacer {
                    Button("Deshacer") { store.deshacer() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: aviso.id) {
                try? await Task.sleep(for: .seconds(6))
                store.cerrarAviso(aviso.id)
            }
        }
    }

    /// Se aplica después de cerrar el panel, para que Camila vea moverse la carta Gantt.
    private func aplicarPropuesta() {
        guard let propuesta = propuestaPendiente else { return }
        propuestaPendiente = nil
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            store.aplicar(propuesta)
        }
    }

    private func aplicarRegistro() {
        guard let pendiente = registroPendiente else { return }
        registroPendiente = nil
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            store.registrar(pendiente.id, registro: pendiente.registro, prepararSiguiente: pendiente.prepararSiguiente)
        }
    }
}
