import SwiftUI

struct ObraView: View {
    @Environment(ObraStore.self) private var store

    /// Lleva a otra pestaña: el programa completo o «Tu avance».
    var alAbrir: (Pestana) -> Void

    @State private var ajustando: Bloque?
    @State private var registrando: Bloque?
    @State private var mostrandoEscenario = false
    @State private var confirmandoReinicio = false
    #if DEBUG
    @State private var depuracionHecha = false
    #endif

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
            .navigationTitle("Mi plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Escenario de demo", systemImage: "slider.horizontal.3") { mostrandoEscenario = true }
                        Button("Reiniciar escenario", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmandoReinicio = true
                        }
                    } label: {
                        Label("Opciones", systemImage: "ellipsis")
                    }
                }
            }
            .hojasDelBloque(ajustando: $ajustando, registrando: $registrando)
            .sheet(isPresented: $mostrandoEscenario) {
                EscenarioSheet()
            }
            .confirmarReinicio($confirmandoReinicio, estado: store.estado) { store.reiniciar() }
            .overlay(alignment: .bottom) { AvisoFlotante() }
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
            ResumenAvanceCard(
                fichas: store.proyecto.visitasPrevias + store.hechos,
                recepcion: store.recepcion,
                corrimiento: store.corrimientoRecepcion,
                ajustes: store.estado.ajustes,
                alAbrir: { alAbrir(.avance) }
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
                trabajo: store.estado.trabajo,
                inicio: store.inicioPrograma,
                ahora: store.ahora,
                diasHolgura: store.diasDeHolgura,
                alVerCompleto: { alAbrir(.programa) }
            )
            .id("gantt")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 110)
        .animation(.snappy, value: store.ajusteSugerido)
        .animation(.snappy, value: store.semanaPorPlanificar)
    }

    #if DEBUG
    /// Una sola vez: al volver a esta pestaña no se repite el ajuste de prueba.
    private func abrirDesdeDepuracion(_ desplazamiento: ScrollViewProxy) {
        guard !depuracionHecha else { return }
        depuracionHecha = true
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
}
