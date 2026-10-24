import SwiftUI

/// «Tu avance»: el muro de fichas, la meta estimada y, al entrar, lo que le funciona y su manual para seguir.
struct AvanceView: View {
    @Environment(ObraStore.self) private var store
    @State private var viendoAprendizajes = false
    #if DEBUG
    @State private var depuracionHecha = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                // Cada sección vive en su propio archivo, así varias sesiones pueden trabajar en paralelo.
                VStack(spacing: 16) {
                    AvanceCard(
                        bloques: store.estado.bloques,
                        proyecto: store.proyecto,
                        inicioObra: store.estado.inicioObra,
                        ahora: store.ahora,
                        recepcion: store.recepcion,
                        corrimiento: store.corrimientoRecepcion,
                        ajustes: store.estado.ajustes,
                        alVerAprendizajes: { viendoAprendizajes = true }
                    )
                    LogrosSeccion()
                    HistorialFotosSeccion()
                    ModoJuegoTarjeta()
                    SabiasQueTarjeta()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tu avance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: ReporteDeAvance(
                            bloques: store.estado.bloques,
                            proyecto: store.proyecto,
                            inicioObra: store.estado.inicioObra,
                            ahora: store.ahora
                        ),
                        preview: SharePreview("Mi avance", image: Image(systemName: "rectangle.split.1x2.fill"))
                    ) {
                        Label("Compartir avance", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationDestination(isPresented: $viendoAprendizajes) {
                AprendizajesView()
            }
            .overlay(alignment: .bottom) { AvisoFlotante() }
            .animation(.spring(duration: 0.4), value: store.aviso)
        }
        #if DEBUG
        .task {
            guard !depuracionHecha else { return }
            depuracionHecha = true
            if Depuracion.abrir == "aprendizajes" { viendoAprendizajes = true }
        }
        #endif
    }
}
