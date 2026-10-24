import SwiftUI

@main
struct EfectoDominoApp: App {
    @State private var store = ObraStore()
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(store)
                .onChange(of: fase) { _, nueva in
                    if nueva == .active { store.notificaciones.actualizar(store.estado) }
                }
        }
    }
}
